/* eslint react-refresh/only-export-components: off -- Agent Doctor 6 (2026-10-16): this entry point selects a page component by URL path. */
import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import './index.css'
import App from './App.jsx'
import ResumeApp from './ResumeApp.jsx'

// Cache public remote photos for offline resume-builder visits.
if ('serviceWorker' in navigator) {
  let warmupRequested = false;
  const requestImageWarmup = (worker) => {
    if (!worker || warmupRequested) return;
    warmupRequested = true;
    worker.postMessage({ type: 'PRECACHE_PUBLIC_IMAGES' });
  };
  navigator.serviceWorker.addEventListener('controllerchange', () => {
    requestImageWarmup(navigator.serviceWorker.controller);
  });
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('/peso-image-cache-worker.js')
      .then(() => navigator.serviceWorker.ready)
      .then((registration) => requestImageWarmup(navigator.serviceWorker.controller || registration.active))
      .catch((error) => console.warn('PESO resume image cache worker could not register.', error));
  });
}

// Check the current URL path
const currentPath = window.location.pathname;

// Default to the PESO Form
let ComponentToRender = App; 

// If Flutter asks for the resume page, swap the component
if (currentPath === '/resume') {
  ComponentToRender = ResumeApp;
}

createRoot(document.getElementById('root')).render(
  <StrictMode>
    <ComponentToRender />
  </StrictMode>,
)