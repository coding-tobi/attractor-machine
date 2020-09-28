import * as tf from "@tensorflow/tfjs";

const ATTRACTOR_RANGE = 0.75;
const MIN_NUM_ATTRACTORS = 1;
const MAX_NUM_ATTRACTORS = 50;
const POINT_RANGE = 1.0;
const MIN_NUM_POINTS = 32;
const MAX_NUM_POINTS = 512;
const MIN_LEARNING_RATE = 0.005;
const MAX_LEARNING_RATE = 0.1;

export default class AttractorMachine {
  private _numAttractors: number = 0;
  private _numParticles: number = 0;
  private _attractors: tf.Tensor2D | null = null;
  private _particles: tf.Variable | null = null;
  private _attractorParticlePairIndices:
    | [tf.Tensor1D, tf.Tensor1D]
    | null = null;
  private _particlePairIndices: [tf.Tensor1D, tf.Tensor1D] | null = null;
  private _optimizer: tf.Optimizer;
  private _isRunning = false;

  protected set attractors(value: tf.Tensor2D) {
    this._attractors?.dispose();
    this._attractors = value;
    this._attractors.data().then((data) => {
      this._attractorsChangedCallback(Array.from(data));
    });

    this.resetOptimizer();
  }

  protected get numAttractors() {
    return this._numAttractors;
  }

  protected set numAttractors(value: number) {
    if (value !== this._numAttractors) {
      this._numAttractors = value;
      this._attractorParticlePairIndices?.forEach((x) => x.dispose());
      this._attractorParticlePairIndices = AttractorMachine.createCartesienProductLikeIndices(
        this._numAttractors,
        this._numParticles
      );

      this.sendStatistics();
    }
  }

  protected get numParticles() {
    return this._numParticles;
  }

  protected set numParticles(value: number) {
    if (value !== this._numParticles) {
      this._numParticles = value;
      this.attractorParticlePairIndices = AttractorMachine.createCartesienProductLikeIndices(
        this._numAttractors,
        this._numParticles
      );
      this.particlePairIndices = AttractorMachine.createPairIndices(
        this._numParticles
      );

      this.sendStatistics();
    }
  }

  protected set particles(value: tf.Variable) {
    this._particles?.dispose();
    this._particles = value;

    this.resetOptimizer();
  }

  protected set attractorParticlePairIndices(
    value: [tf.Tensor1D, tf.Tensor1D]
  ) {
    this._attractorParticlePairIndices?.forEach((x) => x.dispose());
    this._attractorParticlePairIndices = value;
  }

  protected set particlePairIndices(value: [tf.Tensor1D, tf.Tensor1D]) {
    this._particlePairIndices?.forEach((x) => x.dispose());
    this._particlePairIndices = value;
  }

  constructor(
    numAttractors: number,
    numParticles: number,
    private _learningRate: number,
    private _attractorsChangedCallback: (particles: number[]) => void,
    private _optimizationStepCallback: (data: any) => void,
    private _statisticChangedCallback: (data: any) => void
  ) {
    this.numAttractors = numAttractors;
    this.numParticles = numParticles;
    this._optimizer = this.createOptimizer();
    this.shuffleAttractors();
    this.shuffleParticles();
  }

  public run() {
    if (this._isRunning) {
      return;
    } else {
      this._isRunning = true;
      this.optimizationLoop();
    }
  }

  public stop() {
    this._isRunning = false;
  }

  public addAttractors(n: number) {
    const temp = this.numAttractors + n;
    if (MIN_NUM_ATTRACTORS <= temp && temp <= MAX_NUM_ATTRACTORS) {
      this.numAttractors = temp;
      this.shuffleAttractors();
    }
  }

  public shuffleAttractors() {
    this.attractors = tf.randomUniform(
      [this._numAttractors, 2],
      -ATTRACTOR_RANGE,
      ATTRACTOR_RANGE,
      "float32"
    );
  }

  public addParticles(n: number) {
    const temp = this.numParticles + n;
    if (MIN_NUM_POINTS <= temp && temp <= MAX_NUM_POINTS) {
      this.numParticles = temp;
      this.shuffleParticles();
    }
  }

  public shuffleParticles() {
    const temp = tf.randomUniform(
      [this._numParticles, 2],
      -POINT_RANGE,
      POINT_RANGE,
      "float32"
    );
    this.particles = tf.variable(temp);
    temp.dispose();
  }

  public increaseLearningRate(amount: number) {
    // Round at 3 decimal places
    const temp =
      Math.round((this._learningRate + amount + Number.EPSILON) * 1000) / 1000;
    if (MIN_LEARNING_RATE <= temp && temp <= MAX_LEARNING_RATE) {
      this._learningRate = temp;
      this.resetOptimizer();
      this.sendStatistics();
    }
  }

  public dispose() {
    this.stop();
    this._attractors?.dispose();
    this._particles?.dispose();
    this._particlePairIndices?.forEach((x) => x.dispose());
    this._attractorParticlePairIndices?.forEach((x) => x.dispose());
    tf.disposeVariables();
  }

  private resetOptimizer() {
    this._optimizer.dispose();
    this._optimizer = this.createOptimizer();
  }

  private createOptimizer(): tf.Optimizer {
    return tf.train.adam(this._learningRate);
  }

  private optimizationLoop() {
    if (!this._isRunning) {
      return;
    }
    let lastLossValue = 0.0;

    if (
      this._attractors &&
      this._particles &&
      this._attractorParticlePairIndices &&
      this._particlePairIndices
    ) {
      const tempAttractors = this._attractors;
      const tempParticles = this._particles;
      const tempAttractorParticlePairIndices = this
        ._attractorParticlePairIndices;
      const tempParticlePairIndices = this._particlePairIndices;

      this._optimizer.minimize(() => {
        const lastLoss = this.loss(
          tempAttractors,
          tempParticles,
          tempAttractorParticlePairIndices,
          tempParticlePairIndices
        );
        lastLoss.data().then((x) => {
          lastLossValue = x[0];
        });
        return lastLoss;
      });
    }

    // send step-data
    this._particles?.data().then((particlesData) => {
      this._optimizationStepCallback({
        particles: Array.from(particlesData.values()),
        loss: lastLossValue,
        numTensors: tf.memory().numTensors,
      });
    });

    requestAnimationFrame(() => this.optimizationLoop());
  }

  private sendStatistics() {
    this._statisticChangedCallback({
      numAttractors: this._numAttractors,
      numParticles: this._numParticles,
      numPairs:
        (this._particlePairIndices?.[0].shape[0] || 0) +
        (this._attractorParticlePairIndices?.[0].shape[0] || 0),
      learningRate: this._learningRate,
    });
  }

  /**
   * Loss function used for optimization
   */
  private loss(
    attractors: tf.Tensor2D,
    particles: tf.Tensor,
    attractorParticlePairIndices: [tf.Tensor1D, tf.Tensor1D],
    particlePairIndices: [tf.Tensor1D, tf.Tensor1D]
  ): tf.Scalar {
    return AttractorMachine.attractionLoss(
      attractors,
      particles,
      attractorParticlePairIndices
    ).div(AttractorMachine.repulsionGain(particles, particlePairIndices));
  }

  /**
   * Optimize the distance between particles and attractors.
   */
  private static attractionLoss(
    attractors: tf.Tensor2D,
    particles: tf.Tensor,
    [is, js]: [tf.Tensor1D, tf.Tensor1D]
  ): tf.Scalar {
    const as = attractors.gather(is);
    const ps = particles.gather(js);
    const targetDistance = 0.5;
    return ps.sub(as).square().sum(1).sqrt().sub(targetDistance).square().sum();
  }

  /**
   * Maximize the distance between particles.
   */
  private static repulsionGain(
    particles: tf.Tensor,
    [is, js]: [tf.Tensor1D, tf.Tensor1D]
  ): tf.Scalar {
    const pis = particles.gather(is);
    const pjs = particles.gather(js);
    return pjs.sub(pis).square().sum(1).sqrt().sum();
  }

  /**
   * Creates the indices for all pairs of a set with the size of n.
   */
  private static createPairIndices(n: number): [tf.Tensor1D, tf.Tensor1D] {
    const is = [];
    const js = [];
    for (let i = 0; i + 1 < n; i++) {
      for (let j = i + 1; j < n; j++) {
        is.push(i);
        js.push(j);
      }
    }
    return [tf.tensor1d(is, "int32"), tf.tensor1d(js, "int32")];
  }

  /**
   * Creates the indices for something like the cartesien product between two sets.
   */
  private static createCartesienProductLikeIndices(
    m: number,
    n: number
  ): [tf.Tensor1D, tf.Tensor1D] {
    const is = [];
    const js = [];
    for (let i = 0; i < m; i++) {
      for (let j = 0; j < n; j++) {
        is.push(i);
        js.push(j);
      }
    }
    return [tf.tensor1d(is, "int32"), tf.tensor1d(js, "int32")];
  }
}
