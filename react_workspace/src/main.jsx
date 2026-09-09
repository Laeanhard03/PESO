import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import './index.css'
import App from './App.jsx'
import ResumeApp from './ResumeApp.jsx'

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