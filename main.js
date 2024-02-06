import * as THREE from 'three';
import { OrbitControls } from 'three/examples/jsm/controls/OrbitControls.js';
import * as BufferGeometryUtils from 'three/examples/jsm/utils/BufferGeometryUtils.js';
import { GLTFLoader } from 'three/examples/jsm/loaders/GLTFLoader.js';


let scene, camera, renderer, controls;
let targetMesh;


init();
render();

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

  controls = new OrbitControls(camera, renderer.domElement);
  controls.minDistance = 2;
  controls.maxDistance = 5;
  controls.maxPolarAngle = Math.PI / 1.5;
  controls.saveState();
  controls.update();
}

function render() {
  requestAnimationFrame(render);

  renderer.render(scene, camera);
}
