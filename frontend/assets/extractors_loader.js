/**
 * Extractors Loader
 * Utility script to load external extractor modules dynamically
 */

// Keep track of which extractors are loaded
const loadedExtractors = new Set();

// Function to load an extractor script
function loadExtractorScript(name) {
  return new Promise((resolve, reject) => {
    // Skip if already loaded
    if (loadedExtractors.has(name)) {
      console.log(`Extractor ${name} already loaded`);
      resolve(true);
      return;
    }

    console.log(`Loading ${name} extractor...`);
    const script = document.createElement('script');
    
    // Use absolute path or relative path depending on environment
    // For Flutter WebView, we'll use a relative path
    script.src = `assets/${name}_extractor.js`;
    
    script.onload = () => {
      console.log(`Successfully loaded ${name} extractor`);
      loadedExtractors.add(name);
      resolve(true);
    };
    
    script.onerror = (error) => {
      console.error(`Failed to load ${name} extractor`, error);
      reject(error);
    };
    
    document.head.appendChild(script);
  });
}

// Export utilities for extractors to use
function initUtilitiesForExtractors() {
  // Only initialize if not already done
  if (window.ProductDetectorUtils) return;
  
  // Export utilities that will be used by the extractors
  window.ProductDetectorUtils = {
    Logger: window.Logger,
    DOMUtils: window.DOMUtils,
    FormatUtils: window.FormatUtils,
    BaseExtractor: window.BaseExtractor
  };
}

// Load all extractors
async function loadAllExtractors() {
  // Initialize utilities
  initUtilitiesForExtractors();
  
  try {
    // List of extractors to load
    const extractors = [
      'mango'
      // Add other extractors here in the future
      // 'bershka',
      // 'zara', 
      // etc.
    ];
    
    // Load each extractor
    for (const extractor of extractors) {
      try {
        await loadExtractorScript(extractor);
        console.log(`Extractor ${extractor} initialized`);
      } catch (error) {
        console.error(`Failed to load ${extractor} extractor`, error);
      }
    }
    
    console.log('All extractors loaded');
  } catch (e) {
    console.error('Error loading extractors:', e);
  }
}

// Export the loader
window.ExtractorsLoader = {
  loadExtractorScript,
  loadAllExtractors,
  initUtilitiesForExtractors
}; 