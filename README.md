# attractor-machine

Small Elm app wrapped inside a web component. Using (or misusing?) tensorflow.js to animate some interacting particles.

# Get it running

## Prerequisites

1. Install the Elm compiler, following the official Guide: [Install Elm](https://guide.elm-lang.org/install/elm.html)
2. You need npm [Get npm](https://www.npmjs.com/get-npm).
3. Install packages
   ```
   npm install
   ```

## Debugging

1. Compile and start webpack-dev-server
   ```
   npm start
   ```
2. Navigate your browser to http://localhost:9000/

## Build

1. Run the build script:
   ```
   npm run build
   ```
2. Take a loot at the output folder "./dist"!
3. There should be one javascript file, wich defines a web component / custom element named "attractor-machine"!
