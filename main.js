import * as THREE from 'three';
import { OrbitControls } from 'three/examples/jsm/controls/OrbitControls.js';
import * as BufferGeometryUtils from 'three/examples/jsm/utils/BufferGeometryUtils.js';
import { GLTFLoader } from 'three/examples/jsm/loaders/GLTFLoader.js';

// import shaderFragment from './shaders/eyedepth/fragment.glsl';
// import shaderVertex from './shaders/eyedepth/vertex.glsl';

class EyeBall extends THREE.Mesh {
  constructor() {
    let g = new THREE.SphereGeometry(0.1, 64, 32).rotateX(Math.PI * 0.5);
    let m = new THREE.MeshLambertMaterial({
      onBeforeCompile: (shader) => {
        shader.vertexShader = `
          varying vec3 vPos;
          ${shader.vertexShader}
        `.replace(
          `#include <begin_vertex>`,
          `#include <begin_vertex>
            vPos = position;
          `
        );
        console.log(shader.vertexShader);
        shader.fragmentShader = `
          varying vec3 vPos;
          ${shader.fragmentShader}
        `.replace(
          `vec4 diffuseColor = vec4( diffuse, opacity );`,
          `vec4 diffuseColor = vec4( diffuse, opacity );
          
            vec3 dir = vec3(0, 0, 1);
            
            vec3 nPos = normalize(vPos);
            
            float dotProduct = dot(dir, nPos);
            
            float pupil = smoothstep(0.95, 0.97, dotProduct);
            diffuseColor.rgb = mix(diffuseColor.rgb, vec3(0), pupil);
          `
        );
        console.log(shader.fragmentShader);
      },
    });
    super(g, m);
  }
}

class Eyes extends THREE.Group {
  constructor(camera, mouse) {
    super();
    this.camera = camera;

    this.plane = new THREE.Plane();
    this.planeNormal = new THREE.Vector3();
    this.planePoint = new THREE.Vector3();

    this.pointer = new THREE.Vector2();
    this.raycaster = new THREE.Raycaster();

    this.lookAt = new THREE.Vector3();

    this.eyes = new Array(2).fill().map((_, idx) => {
      let eye = new EyeBall();
      eye.position.x = idx < 1 ? 0 : 0.87;
      eye.position.y = idx < 1 ? 0 : 0.05;
      eye.position.z = idx < 1 ? 0 : -0.1;
      this.add(eye);
      return eye;
    });

    document.addEventListener('pointermove', (event) => {
      this.pointer.x = (event.clientX / window.innerWidth) * 2 - 1;
      this.pointer.y = -(event.clientY / window.innerHeight) * 2 + 1;
    });
  }

  update() {
    this.raycaster.setFromCamera(this.pointer, this.camera);

    this.camera.getWorldDirection(this.planeNormal);
    this.planePoint
      .copy(this.planeNormal)
      .setLength(5)
      .add(this.camera.position);
    this.plane.setFromNormalAndCoplanarPoint(this.planeNormal, this.planePoint);

    this.raycaster.ray.intersectPlane(this.plane, this.lookAt);

    this.lookAt.set(this.lookAt.x, this.lookAt.y, this.camera.position.z);
    this.eyes.forEach((eye) => {
      eye.lookAt(this.lookAt);
    });
  }
}

let scene, camera, renderer, controls;
let targetMesh;
let eyes;


init();

function init() {

  // renderer setup
  renderer = new THREE.WebGLRenderer({ antialias: true });
  renderer.setPixelRatio(window.devicePixelRatio);
  renderer.setSize(window.innerWidth, window.innerHeight);
  document.body.appendChild(renderer.domElement);

  // scene setup
  scene = new THREE.Scene();

  const light = new THREE.DirectionalLight(0xffffff, 0.7);
  light.position.set(1, 1, 1);
  scene.add(light);
  scene.add(new THREE.AmbientLight(0xffffff, 0.4));

  // camera setup
  camera = new THREE.PerspectiveCamera(
    75,
    window.innerWidth / window.innerHeight,
    0.1,
    50
  );
  camera.position.set(0, 0, 3);
  camera.far = 50;
  camera.updateProjectionMatrix();

  const loader = new GLTFLoader();
  loader.load(
    './model/duck-head.glb',
    (gltf) => {
      targetMesh = gltf.scene.children[0];
      targetMesh.geometry = BufferGeometryUtils.mergeVertices(targetMesh.geometry);
      targetMesh.geometry.attributes.position.setUsage(THREE.DynamicDrawUsage);
      targetMesh.geometry.attributes.normal.setUsage(THREE.DynamicDrawUsage);
      scene.add(targetMesh);
    },
    undefined,
    (error) => {
      console.error(error);
    }
  );

  eyes = new Eyes(camera);
  eyes.position.set(-0.18, -0.42, 0.5);
  scene.add(eyes);

  controls = new OrbitControls(camera, renderer.domElement);
  controls.minDistance = 2;
  controls.maxDistance = 5;
  controls.maxPolarAngle = Math.PI / 1.5;
  controls.saveState();
  controls.update();
  render();
}

function render() {
  requestAnimationFrame(render);

  eyes.update();

  renderer.render(scene, camera);
}
