import AttractorMachine from "./attractor-machine";

import { library, config, dom } from "@fortawesome/fontawesome-svg-core";
import {
  faDice,
  faEye,
  faEyeSlash,
  faMinus,
  faPlus,
  faRedo,
} from "@fortawesome/free-solid-svg-icons";

import CSS from "../style.css";

export default class AttractorMachineComponent extends HTMLElement {
  private machine: AttractorMachine | null;
  private root: ShadowRoot;

  constructor() {
    super();
    this.machine = null;
    this.root = this.attachShadow({ mode: "closed" });

    // Attach styles
    const style = document.createElement("style");
    style.textContent = CSS;
    this.root.appendChild(style);

    // Setup fontawesome
    // ... config
    config.autoAddCss = false;
    config.autoReplaceSvg = "nest";

    // ... add css styles
    const faStyle = document.createElement("style");
    faStyle.textContent = dom.css();
    this.root.appendChild(faStyle);

    // ... add icons to library
    library.add(faDice, faEye, faEyeSlash, faMinus, faPlus, faRedo);

    // ... watch my shadow-dom root
    (<any>dom).watch({
      autoReplaceSvgRoot: this.root,
      observeMutationsRoot: this.root,
    });
  }

  protected connectedCallback() {
    if (!this.isConnected) {
      return;
    }

    const elmAppDiv = document.createElement("div");
    this.root.appendChild(elmAppDiv);

    // Create the elm-app
    const elm = require("../elm/src/Attractor.elm").Elm;
    const app = elm.Attractor.init({
      node: elmAppDiv,
    });

    // Create the attractor-machine
    this.machine = new AttractorMachine(
      5,
      64,
      0.025,
      app.ports.attractorsChanged.send,
      app.ports.optimizationStep.send,
      app.ports.statisticChanged.send
    );

    // Connect ports for elm-to-js interop
    app.ports.runMachine.subscribe(() => {
      this.machine?.run();
    });
    app.ports.stopMachine.subscribe(() => {
      this.machine?.stop();
    });
    app.ports.addAttractors.subscribe((n: number) => {
      this.machine?.addAttractors(n);
    });
    app.ports.shuffleAttractors.subscribe(() => {
      this.machine?.shuffleAttractors();
    });
    app.ports.addParticles.subscribe((n: number) => {
      this.machine?.addParticles(n);
    });
    app.ports.shuffleParticles.subscribe(() => {
      this.machine?.shuffleParticles();
    });
    app.ports.increaseLearningRate.subscribe((v: number) => {
      this.machine?.increaseLearningRate(v);
    });
  }

  protected disconnectedCallback() {
    this.machine?.dispose();
    this.machine = null;
  }
}
