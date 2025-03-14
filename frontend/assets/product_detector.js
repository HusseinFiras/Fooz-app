/**
 * Enhanced Product Detection Script with Improved Debugging for E-commerce WebViews
 */

// Debug Configuration - Easy to toggle
const DEBUG = {
  enabled: true, // Master toggle for all debugging
  methods: true, // Log detection methods being tried
  selectors: false, // Log individual selectors being checked (very noisy)
  dom: false, // Log detailed DOM inspection (extremely verbose)
  data: true, // Log extracted data before processing
  timing: false, // Log timing information (useful for performance analysis)
  errorVerbose: true, // Show verbose error information
  level: "info", // 'error', 'warn', 'info', 'debug', 'trace'

  // Filter options
  filterSelectors: true, // Only log selectors that succeeded
  maxArrayLength: 3, // Maximum number of array items to show in logs
  truncateText: 100, // Maximum length for text in logs

  // Group certain logs to reduce clutter
  groupLogs: true, // Group related logs together
  expandGroups: false, // Auto-expand grouped logs
};

const debug = {
  // Private formatting helpers
  _formatValue: function (value) {
    if (value === null || value === undefined) return String(value);

    if (typeof value === "string") {
      if (value.length > DEBUG.truncateText) {
        return value.substring(0, DEBUG.truncateText) + "... (truncated)";
      }
      return value;
    }

    if (Array.isArray(value)) {
      if (value.length > DEBUG.maxArrayLength) {
        return `Array(${value.length}) [${value
          .slice(0, DEBUG.maxArrayLength)
          .map((v) => this._formatValue(v))
          .join(", ")}...]`;
      }
    }

    if (typeof value === "object" && value !== null) {
      // For DOM elements, show a simplified representation
      if (value.nodeType === 1) {
        return `<${value.tagName.toLowerCase()}${
          value.id ? ' id="' + value.id + '"' : ""
        }${value.className ? ' class="' + value.className + '"' : ""}>`;
      }

      // For objects, limit content display
      try {
        const simpleObj = {};
        let count = 0;
        for (const key in value) {
          if (count < 5 && value.hasOwnProperty(key)) {
            simpleObj[key] = this._formatValue(value[key]);
            count++;
          }
          if (count >= 5) {
            simpleObj["..."] = `(${
              Object.keys(value).length - 5
            } more properties)`;
            break;
          }
        }
        return simpleObj;
      } catch (e) {
        return "[Object]";
      }
    }

    return value;
  },

  _getPrefix: function (level, category) {
    const timestamp = new Date().toISOString().substr(11, 8);
    return `[${timestamp}][${category.toUpperCase()}]`;
  },

  // Public logging methods
  info: function (message, data) {
    if (!DEBUG.enabled || DEBUG.level === "error" || DEBUG.level === "warn")
      return;
    console.info(
      `${this._getPrefix("info", "info")} ${message}`,
      data ? this._formatValue(data) : ""
    );
  },

  success: function (message, data) {
    if (!DEBUG.enabled || DEBUG.level === "error" || DEBUG.level === "warn")
      return;
    console.log(
      `${this._getPrefix("success", "success")} ✅ ${message}`,
      data ? this._formatValue(data) : ""
    );
  },

  error: function (message, data) {
    if (!DEBUG.enabled) return;
    console.error(
      `${this._getPrefix("error", "error")} ❌ ${message}`,
      data ? this._formatValue(data) : ""
    );
  },

  warn: function (message, data) {
    if (!DEBUG.enabled || DEBUG.level === "error") return;
    console.warn(
      `${this._getPrefix("warn", "warn")} ⚠️ ${message}`,
      data ? this._formatValue(data) : ""
    );
  },

  // Method tracking with less verbosity
  method: {
    start: function (methodName) {
      if (!DEBUG.enabled || !DEBUG.methods) return null;
      if (DEBUG.level === "trace" || DEBUG.level === "debug") {
        console.debug(
          `${debug._getPrefix("debug", "method")} Starting: ${methodName}`
        );
      }
      return performance.now();
    },

    end: function (methodName, startTime, result) {
      if (!DEBUG.enabled || !DEBUG.methods || !startTime) return;
      const success =
        result &&
        (result.success === true ||
          (typeof result === "object" && Object.keys(result).length > 0));

      if (DEBUG.level === "trace" || DEBUG.level === "debug" || success) {
        const duration = performance.now() - startTime;
        console[success ? "log" : "debug"](
          `${debug._getPrefix(
            success ? "info" : "debug",
            "method"
          )} ${methodName} ${success ? "✅" : "❌"} (${duration.toFixed(0)}ms)`,
          success ? debug._formatValue(result) : ""
        );
      }
    },
  },

  // Selector checking with filtering
  selector: {
    check: function (selector, element, context = "") {
      if (!DEBUG.enabled || !DEBUG.selectors) return;
      if (DEBUG.filterSelectors && !element) return;

      if (DEBUG.level === "trace" || DEBUG.level === "debug") {
        const found = !!element;
        console.debug(
          `${debug._getPrefix("debug", "selector")} ${
            found ? "✅" : "❌"
          } ${context} Selector: ${selector}`
        );
      }
    },

    checkAll: function (selectors, foundElement, context = "") {
      if (!DEBUG.enabled || !DEBUG.selectors) return;
      if (DEBUG.filterSelectors && !foundElement) return;

      if (DEBUG.level === "trace" || DEBUG.level === "debug") {
        if (foundElement) {
          const matchingSelector = selectors.find(
            (s) => document.querySelector(s) === foundElement
          );
          console.debug(
            `${debug._getPrefix(
              "debug",
              "selector"
            )} ✅ ${context} Found match with: ${matchingSelector}`
          );
        }
      }
    },
  },

  // Data logging with cleaner output
  data: {
    extracted: function (source, data) {
      if (!DEBUG.enabled || !DEBUG.data) return;

      if (DEBUG.groupLogs) {
        console.groupCollapsed(
          `${debug._getPrefix("debug", "data")} From ${source}`
        );
        console.log(debug._formatValue(data));
        console.groupEnd();
      } else {
        console.log(
          `${debug._getPrefix("debug", "data")} From ${source}:`,
          debug._formatValue(data)
        );
      }
    },

    processed: function (stage, data) {
      if (!DEBUG.enabled || !DEBUG.data) return;

      if (DEBUG.groupLogs) {
        console.groupCollapsed(
          `${debug._getPrefix("debug", "data")} Processed (${stage})`
        );
        console.log(debug._formatValue(data));
        console.groupEnd();
      } else {
        console.log(
          `${debug._getPrefix("debug", "data")} Processed (${stage}):`,
          debug._formatValue(data)
        );
      }
    },

    sent: function (data) {
      if (!DEBUG.enabled || !DEBUG.data) return;

      // Always log data sent to Flutter clearly
      if (DEBUG.groupLogs) {
        console.group(
          `${debug._getPrefix("info", "data")} 📤 Sending to Flutter`
        );
        console.log(debug._formatValue(data));
        console.groupEnd();
      } else {
        console.log(
          `${debug._getPrefix("info", "data")} 📤 Sending to Flutter:`,
          debug._formatValue(data)
        );
      }
    },
  },

  // Simple timing logs
  timing: {
    start: function (label) {
      if (!DEBUG.enabled || !DEBUG.timing) return null;
      if (DEBUG.level === "trace" || DEBUG.level === "debug") {
        console.debug(
          `${debug._getPrefix("debug", "timing")} ⏱️ Started: ${label}`
        );
      }
      return performance.now();
    },

    end: function (label, startTime) {
      if (!DEBUG.enabled || !DEBUG.timing || !startTime) return;

      if (DEBUG.level === "trace" || DEBUG.level === "debug") {
        const duration = performance.now() - startTime;
        console.debug(
          `${debug._getPrefix(
            "debug",
            "timing"
          )} ⏱️ Finished: ${label} (${duration.toFixed(0)}ms)`
        );
      }
    },
  },

  // Clear the console
  clear: function () {
    console.clear();
    console.log(`${this._getPrefix("info", "debug")} Console cleared`);
  },
};

// Override console.error to filter out noise from WebView
const originalConsoleError = console.error;
console.error = function (...args) {
  // Filter out common WebView errors that aren't helpful
  const errorText = args.join(" ");
  const ignorePatterns = [
    "ResizeObserver",
    "The XDG_",
    "Failed to load resource",
    "JQMIGRATE",
    "ServiceWorker",
    "Mixed Content",
    "Audit",
    "Non-passive event listener",
    "Request was interrupted",
    "SourceMap",
  ];

  if (ignorePatterns.some((pattern) => errorText.includes(pattern))) {
    // Skip these errors entirely
    return;
  }

  // Let through other errors
  originalConsoleError.apply(console, args);
};

// Clean up console warnings too
const originalConsoleWarn = console.warn;
console.warn = function (...args) {
  // Filter out common WebView warnings that aren't helpful
  const warnText = args.join(" ");
  const ignorePatterns = [
    "JQMIGRATE",
    "ResizeObserver",
    "localStorage",
    "sessionStorage",
    "Content Security Policy",
    "Synchronous XMLHttpRequest",
    "DevTools",
    "Cookies",
    "CORS",
  ];

  if (ignorePatterns.some((pattern) => warnText.includes(pattern))) {
    // Skip these warnings entirely
    return;
  }

  // Let through other warnings
  originalConsoleWarn.apply(console, args);
};

// Initialize with a clean console
setTimeout(() => {
  if (DEBUG.enabled) {
    debug.clear();
    debug.info("🔍 Product Detector initialized with clean debugging", {
      url: window.location.href,
      title: document.title,
    });
  }
}, 100);

// Initialize the product detector when the script is loaded
(function () {
  // Configure debug logger
  initializeDebugger();

  // Start script with shorter delay to be more responsive
  const initTimer = debug.timing.start("Initialization");
  setTimeout(() => {
    initProductDetector();
    debug.timing.end("Initialization", initTimer);
  }, 500);
})();

/**
 * Initialize debug logging system
 */
function initializeDebugger() {
  // Simple debug system
  window.debug = {
    log: function (level, category, message, data) {
      if (!DEBUG.enabled) return;

      // Format timestamp for logs
      const timestamp = new Date().toISOString().substr(11, 8);

      // Choose style based on level and category
      const styles = {
        error:
          "background:#f8d7da; color:#721c24; padding:2px 5px; border-radius:3px;",
        warn: "background:#fff3cd; color:#856404; padding:2px 5px; border-radius:3px;",
        info: "background:#d1ecf1; color:#0c5460; padding:2px 5px; border-radius:3px;",
        success:
          "background:#d4edda; color:#155724; padding:2px 5px; border-radius:3px;",
        debug:
          "background:#e2e3e5; color:#383d41; padding:2px 5px; border-radius:3px;",
        method:
          "background:#cce5ff; color:#004085; padding:2px 5px; border-radius:3px;",
        data: "color:#6610f2; font-weight:bold;",
        timing: "color:#fd7e14;",
      };

      const style = styles[category] || styles[level] || "";

      // Format the prefix for the log
      const prefix = `%c[${timestamp}][${category.toUpperCase()}]`;

      // Log the message with appropriate styling
      if (data !== null && data !== undefined) {
        console.groupCollapsed(`${prefix} ${message}`, style);
        console.log("Details:", data);
        console.groupEnd();
      } else {
        console.log(`${prefix} ${message}`, style);
      }
    },

    // Core logging methods
    info: function (message, data) {
      this.log("info", "info", message, data);
    },

    error: function (message, data) {
      this.log("error", "error", message, data);
    },

    success: function (message, data) {
      this.log("info", "success", message, data);
    },

    // Method tracking
    method: {
      start: function (methodName) {
        if (!DEBUG.methods) return null;
        debug.log("debug", "method", `Starting: ${methodName}`);
        return performance.now();
      },

      end: function (methodName, startTime, result) {
        if (!DEBUG.methods || !startTime) return;
        const duration = performance.now() - startTime;
        const success =
          result && (result.success === true || Object.keys(result).length > 0);
        debug.log(
          "debug",
          "method",
          `${methodName} ${success ? "✅" : "❌"} (${duration.toFixed(2)}ms)`,
          result
        );
        return duration;
      },
    },

    // Selector tracking
    selector: {
      check: function (selector, element, context = "") {
        if (!DEBUG.selectors) return;
        const found = !!element;
        debug.log(
          "debug",
          "selector",
          `${found ? "✅" : "❌"} ${context} Selector: ${selector}`,
          found ? { text: element.textContent?.trim() } : null
        );
      },

      checkAll: function (selectors, foundElement, context = "") {
        if (!DEBUG.selectors) return;
        if (foundElement) {
          const matchingSelector = selectors.find(
            (s) => document.querySelector(s) === foundElement
          );
          debug.log(
            "debug",
            "selector",
            `✅ ${context} Found match with: ${matchingSelector}`,
            { element: foundElement, text: foundElement.textContent?.trim() }
          );
        } else {
          debug.log(
            "debug",
            "selector",
            `❌ ${context} None of these selectors matched: ${selectors.join(
              ", "
            )}`
          );
        }
      },
    },

    // Data tracking
    data: {
      extracted: function (source, data) {
        if (!DEBUG.data) return;
        debug.log("debug", "data", `From ${source}:`, data);
      },

      processed: function (stage, data) {
        if (!DEBUG.data) return;
        debug.log("debug", "data", `Processed (${stage}):`, data);
      },

      sent: function (data) {
        if (!DEBUG.data) return;
        debug.log("info", "data", `Sending to Flutter:`, data);
      },
    },

    // Timing functions
    timing: {
      start: function (label) {
        if (!DEBUG.timing) return null;
        debug.log("debug", "timing", `⏱️ Started: ${label}`);
        return performance.now();
      },

      end: function (label, startTime) {
        if (!DEBUG.timing || !startTime) return;
        const duration = performance.now() - startTime;
        debug.log(
          "debug",
          "timing",
          `⏱️ Finished: ${label} (${duration.toFixed(2)}ms)`
        );
        return duration;
      },
    },
  };

  // Log initial debug information
  debug.info("Product Detector debugging initialized", {
    url: window.location.href,
    title: document.title,
  });
}

/**
 * Main function to initialize product detection
 */
function initProductDetector() {
  // Configuration - optimized timing values
  const CHECK_INTERVAL = 800;
  const MAX_RETRIES = 5;
  const RETRY_DELAY = 600;
  const NAVIGATION_CHECK_INTERVAL = 300;

  let retryCount = 0;
  let lastProductData = null;
  let productDetected = false;
  let observer = null;
  let initialAttemptComplete = false;

  debug.info("Product Detector initialized", {
    checkInterval: CHECK_INTERVAL,
    maxRetries: MAX_RETRIES,
  });

  // Function to report data back to Flutter
  function reportToFlutter(data) {
    if (window.FlutterChannel) {
      debug.data.sent(data);
      window.FlutterChannel.postMessage(JSON.stringify(data));
    } else {
      debug.error("FlutterChannel not available for communication");
    }
  }

  // Main product detection function
  function detectAndReportProduct() {
    const detectionTimer = debug.timing.start(
      "Product Detection (Full Process)"
    );

    debug.info("Starting product detection");
    const productData = extractProductInfo();

    debug.data.processed("final", productData);

    // If we've already detected and reported this product, don't report again
    // unless something significant changed
    if (lastProductData && productData.success) {
      if (
        lastProductData.title === productData.title &&
        lastProductData.price === productData.price
      ) {
        debug.info("Skipping report - product unchanged");
        debug.timing.end("Product Detection (Full Process)", detectionTimer);
        return;
      }
    }

    // Store the last detected product data
    lastProductData = productData;

    // Report the data back to Flutter
    reportToFlutter(productData);

    // If we found a product, set the flag
    if (productData.success) {
      productDetected = true;
      initialAttemptComplete = true;
      debug.success("Product successfully detected!");
      debug.timing.end("Product Detection (Full Process)", detectionTimer);
      return true;
    }

    // If this is our first complete attempt with no success
    if (!initialAttemptComplete) {
      initialAttemptComplete = true;

      // If it's clearly not a product page, stop trying aggressively
      if (!productData.isProductPage) {
        debug.info("Not a product page, reducing retry attempts");

        reportToFlutter({
          isProductPage: false,
          success: false,
          navigated: false,
          url: window.location.href,
        });

        // Reduce the retry count to minimize background processing
        retryCount = MAX_RETRIES - 2;
      }
    }

    debug.timing.end("Product Detection (Full Process)", detectionTimer);
    return false;
  }

  // Function to retry detection with increasing delays
  function retryDetection() {
    if (retryCount >= MAX_RETRIES || productDetected) {
      debug.info(
        `Retry limit reached (${retryCount}/${MAX_RETRIES}) or product already detected`
      );
      return;
    }

    retryCount++;
    debug.info(
      `Scheduling retry #${retryCount} in ${RETRY_DELAY * retryCount}ms`
    );

    setTimeout(() => {
      if (!detectAndReportProduct()) {
        retryDetection();
      }
    }, RETRY_DELAY * retryCount);
  }

  // Initial detection - use a more immediate first check
  setTimeout(detectAndReportProduct, 100);

  // Then follow with normal retry pattern
  setTimeout(() => {
    if (!productDetected) {
      debug.info(
        "Initial detection didn't find product, starting retry sequence"
      );
      retryDetection();
    }
  }, 700);
}

/**
 * Function to check if current page is a product page
 */
function isProductPage() {
  const pageCheckTimer = debug.timing.start("Check if Product Page");

  debug.info("Checking if current page is a product page");

  // 1. Check URL patterns
  const url = window.location.href;
  debug.info(`Current URL: ${url}`);

  const productUrlPatterns = [
    /\/p\//,
    /\/product\//,
    /\/item\//,
    /\/pd\//,
    /\/products\//,
    /\/urun\//,
    /\/detay\//,
    /\/ProductDetails/,
    /\/productdetail/,
    /\/goods\//,
    /\/shop\/products\//,
    /\/product-p/,
    /\/[a-z0-9-_]{6,}\/p\/[a-z0-9-_]{6,}/,
  ];

  for (const pattern of productUrlPatterns) {
    if (pattern.test(url)) {
      debug.success(`URL matches product pattern: ${pattern}`);
      debug.timing.end("Check if Product Page", pageCheckTimer);
      return true;
    }
  }

  // 2. Check for schema.org product markup
  const jsonLdScripts = document.querySelectorAll(
    'script[type="application/ld+json"]'
  );
  debug.info(`Found ${jsonLdScripts.length} JSON-LD scripts`);

  for (const script of jsonLdScripts) {
    try {
      const data = JSON.parse(script.textContent);
      debug.data.extracted("json-ld script", data);

      if (
        data["@type"] === "Product" ||
        (Array.isArray(data) &&
          data.some((item) => item["@type"] === "Product"))
      ) {
        debug.success("Found Product type in JSON-LD");
        debug.timing.end("Check if Product Page", pageCheckTimer);
        return true;
      }
    } catch (e) {
      debug.error("Error parsing JSON-LD script", e);
      // JSON parsing error, continue to next script
    }
  }

  // 3. Check for product-specific meta tags
  const metaProductType = document.querySelector(
    'meta[property="og:type"][content="product"]'
  );
  const metaProductPrice = document.querySelector(
    'meta[property="product:price:amount"]'
  );

  debug.selector.check(
    'meta[property="og:type"][content="product"]',
    metaProductType,
    "Meta Tag"
  );
  debug.selector.check(
    'meta[property="product:price:amount"]',
    metaProductPrice,
    "Meta Tag"
  );

  if (metaProductType || metaProductPrice) {
    debug.success("Found product meta tags");
    debug.timing.end("Check if Product Page", pageCheckTimer);
    return true;
  }

  // 4. Check for common product page elements
  const productIndicators = [
    // Add to cart buttons
    ".add-to-cart",
    "#addToCart",
    '[data-button-action="add-to-cart"]',
    ".btn-add-to-cart",
    ".addtocart",
    ".AddToCart",
    ".sepeteekle",
    // Product galleries
    ".product-gallery",
    ".product-images",
    ".product-photos",
    ".product-image-gallery",
    ".urun-resimleri",
    // Product options (like size/color selectors)
    ".product-options",
    ".product-variants",
    ".size-selector",
    ".variant-options",
    ".product-form__variants",
    ".urun-secenekleri",
  ];

  // Track matches
  let foundIndicator = null;
  for (const selector of productIndicators) {
    const element = document.querySelector(selector);
    if (element) {
      foundIndicator = { selector, element };
      break;
    }
  }

  if (foundIndicator) {
    debug.success(`Found product indicator: ${foundIndicator.selector}`);
    debug.timing.end("Check if Product Page", pageCheckTimer);
    return true;
  }

  // 5. Check for typical product page structure
  const priceElement = document.querySelector('[itemprop="price"]');
  debug.selector.check('[itemprop="price"]', priceElement, "Price Element");

  // Check for price pattern in text
  const hasPricePattern = !!document.body.innerText.match(
    /[0-9]+[,.][0-9]+\s*(TL|₺|\$|€|£)/
  );
  debug.info(`Price pattern in page text: ${hasPricePattern}`);

  // Check for product title
  const titleElement = document.querySelector("h1");
  const titleCount = document.querySelectorAll("h1").length;
  debug.info(
    `Title elements: ${titleCount}`,
    titleElement ? { text: titleElement.textContent } : null
  );

  const hasProductTitle = titleElement && titleCount < 3; // Usually just one main title

  const result = (priceElement || hasPricePattern) && hasProductTitle;

  if (result) {
    debug.success("Page has price and title elements typical of product pages");
  } else {
    debug.info("Page structure doesn't match typical product page");
  }

  debug.timing.end("Check if Product Page", pageCheckTimer);
  return result;
}

/**
 * Main function to extract product information using multiple methods
 */
function extractProductInfo() {
  const extractionTimer = debug.timing.start("Extract Product Info");

  // Create a result object
  const result = {
    isProductPage: isProductPage(),
    title: null,
    price: null,
    originalPrice: null,
    currency: null,
    imageUrl: null,
    description: null,
    sku: null,
    availability: null,
    brand: null,
    variants: null,
    extractionMethod: null,
    url: window.location.href,
    timestamp: new Date().toISOString(),
    success: false,
  };

  debug.info(
    `Page analysis: ${
      result.isProductPage ? "This is a product page" : "Not a product page"
    }`
  );

  if (!result.isProductPage) {
    debug.timing.end("Extract Product Info", extractionTimer);
    return result;
  }

  // Extract variant information using dedicated function
  const variantTimer = debug.timing.start("Extract Variants");
  result.variants = extractVariantInfo();
  debug.data.extracted("variants", result.variants);
  debug.timing.end("Extract Variants", variantTimer);

  // Use multiple methods to extract data, starting with the most reliable

  // Method 1: Structured data (schema.org)
  const structuredTimer = debug.method.start("extractFromStructuredData");
  const structuredData = extractFromStructuredData();
  const structuredResult = debug.method.end(
    "extractFromStructuredData",
    structuredTimer,
    structuredData
  );

  if (structuredData.success) {
    debug.success("Successfully extracted data from structured data");
    Object.assign(result, structuredData);
    result.extractionMethod = "structured_data";
    result.success = true;
    debug.timing.end("Extract Product Info", extractionTimer);
    return result;
  }

  // Method 2: Meta tags
  const metaTimer = debug.method.start("extractFromMetaTags");
  const metaTags = extractFromMetaTags();
  debug.method.end("extractFromMetaTags", metaTimer, metaTags);

  if (metaTags.success) {
    debug.success("Successfully extracted data from meta tags");
    Object.assign(result, metaTags);
    result.extractionMethod = "meta_tags";
    result.success = true;
    debug.timing.end("Extract Product Info", extractionTimer);
    return result;
  }

  // Method 3: Common selectors
  const selectorTimer = debug.method.start("extractFromCommonSelectors");
  const commonSelectors = extractFromCommonSelectors();
  debug.method.end(
    "extractFromCommonSelectors",
    selectorTimer,
    commonSelectors
  );

  if (commonSelectors.success) {
    debug.success("Successfully extracted data from common selectors");
    Object.assign(result, commonSelectors);
    result.extractionMethod = "common_selectors";
    result.success = true;
    debug.timing.end("Extract Product Info", extractionTimer);
    return result;
  }

  // Method 4: Content scanning (least reliable, but fallback)
  const scanTimer = debug.method.start("scanContentForProductInfo");
  const contentScan = scanContentForProductInfo();
  debug.method.end("scanContentForProductInfo", scanTimer, contentScan);

  if (contentScan.success) {
    debug.success("Successfully extracted data from content scanning");
    Object.assign(result, contentScan);
    result.extractionMethod = "content_scan";
    result.success = true;
    debug.timing.end("Extract Product Info", extractionTimer);
    return result;
  }

  debug.info("All extraction methods failed");
  debug.timing.end("Extract Product Info", extractionTimer);
  return result;
}

/**
 * Extract product info from structured data (JSON-LD)
 */
function extractFromStructuredData() {
  const structuredDataTimer = debug.timing.start("Structured Data Extraction");

  debug.info("Attempting extraction from structured data (JSON-LD)");

  const result = {
    title: null,
    price: null,
    originalPrice: null,
    currency: null,
    imageUrl: null,
    description: null,
    sku: null,
    availability: null,
    brand: null,
    success: false,
  };

  const jsonLdScripts = document.querySelectorAll(
    'script[type="application/ld+json"]'
  );

  debug.info(`Found ${jsonLdScripts.length} JSON-LD scripts to examine`);

  for (const script of jsonLdScripts) {
    try {
      const data = JSON.parse(script.textContent);
      debug.data.extracted("json-ld script", data);

      // Function to find product data regardless of nesting
      const findProduct = (obj) => {
        if (!obj) return null;

        if (obj["@type"] === "Product") {
          debug.success("Found product object in JSON-LD");
          return obj;
        }

        if (Array.isArray(obj)) {
          for (const item of obj) {
            const result = findProduct(item);
            if (result) return result;
          }
        } else if (typeof obj === "object") {
          for (const key in obj) {
            const result = findProduct(obj[key]);
            if (result) return result;
          }
        }

        return null;
      };

      const product = findProduct(data);

      if (product) {
        debug.data.extracted("structured data product", product);

        result.title = product.name || null;
        result.description = product.description || null;
        result.sku = product.sku || product.mpn || null;

        // Extract brand information
        if (product.brand) {
          if (typeof product.brand === "string") {
            result.brand = product.brand;
          } else if (product.brand.name) {
            result.brand = product.brand.name;
          }
        }

        // Handle image URLs
        if (product.image) {
          debug.info("Processing image data", product.image);

          if (typeof product.image === "string") {
            result.imageUrl = makeImageUrlAbsolute(product.image);
          } else if (Array.isArray(product.image) && product.image.length > 0) {
            const imgUrl = product.image[0].url || product.image[0];
            result.imageUrl = makeImageUrlAbsolute(imgUrl);
          } else if (product.image.url) {
            result.imageUrl = makeImageUrlAbsolute(product.image.url);
          }

          debug.info(`Resolved image URL: ${result.imageUrl}`);
        }

        // Handle offers/pricing
        if (product.offers) {
          let offer = product.offers;
          debug.info("Processing offers data", offer);

          if (Array.isArray(offer)) {
            offer = offer[0]; // Take the first offer
            debug.info("Multiple offers found, using first one", offer);
          }

          if (offer) {
            result.price = offer.price || offer.lowPrice || null;
            result.currency = offer.priceCurrency || null;
            result.availability =
              formatAvailability(offer.availability) || null;

            // Check for original price
            if (offer.highPrice && offer.highPrice > offer.price) {
              result.originalPrice = offer.highPrice;
              debug.info(`Original price found: ${result.originalPrice}`);
            }
          }
        }

        if (result.title && result.price) {
          result.success = true;
          debug.success(
            "Successfully extracted product data from structured data",
            result
          );
          debug.timing.end("Structured Data Extraction", structuredDataTimer);
          return result;
        }
      }
    } catch (e) {
      debug.error("Error parsing JSON-LD script", e);
      // JSON parsing error, continue to next script
    }
  }

  debug.info("Could not extract complete product data from structured data");
  debug.timing.end("Structured Data Extraction", structuredDataTimer);
  return result;
}

/**
 * Extract product info from meta tags
 */
function extractFromMetaTags() {
  const metaTagsTimer = debug.timing.start("Meta Tags Extraction");

  debug.info("Attempting extraction from meta tags");

  const result = {
    title: null,
    price: null,
    originalPrice: null,
    currency: null,
    imageUrl: null,
    description: null,
    sku: null,
    availability: null,
    brand: null,
    success: false,
  };

  // Product title
  const titleMeta = document.querySelector(
    'meta[property="og:title"], meta[name="twitter:title"]'
  );
  debug.selector.check(
    'meta[property="og:title"], meta[name="twitter:title"]',
    titleMeta,
    "Title"
  );

  if (titleMeta) {
    result.title = titleMeta.getAttribute("content");
    debug.info(`Found title in meta tags: ${result.title}`);
  }

  // Product price
  const priceMeta = document.querySelector(
    'meta[property="product:price:amount"], meta[property="og:price:amount"]'
  );
  debug.selector.check(
    'meta[property="product:price:amount"], meta[property="og:price:amount"]',
    priceMeta,
    "Price"
  );

  if (priceMeta) {
    const price = priceMeta.getAttribute("content");
    if (price && !isNaN(parseFloat(price))) {
      result.price = price;
      debug.info(`Found price in meta tags: ${result.price}`);
    }
  }

  // Currency
  const currencyMeta = document.querySelector(
    'meta[property="product:price:currency"], meta[property="og:price:currency"]'
  );
  debug.selector.check(
    'meta[property="product:price:currency"], meta[property="og:price:currency"]',
    currencyMeta,
    "Currency"
  );

  if (currencyMeta) {
    result.currency = currencyMeta.getAttribute("content");
    debug.info(`Found currency in meta tags: ${result.currency}`);
  }

  // Product image
  const imageMeta = document.querySelector(
    'meta[property="og:image"], meta[name="twitter:image"]'
  );
  debug.selector.check(
    'meta[property="og:image"], meta[name="twitter:image"]',
    imageMeta,
    "Image"
  );

  if (imageMeta) {
    result.imageUrl = makeImageUrlAbsolute(imageMeta.getAttribute("content"));
    debug.info(`Found image in meta tags: ${result.imageUrl}`);
  }

  // Product description
  const descMeta = document.querySelector(
    'meta[property="og:description"], meta[name="twitter:description"], meta[name="description"]'
  );
  debug.selector.check(
    'meta[property="og:description"], meta[name="twitter:description"], meta[name="description"]',
    descMeta,
    "Description"
  );

  if (descMeta) {
    result.description = descMeta.getAttribute("content");
    debug.info(`Found description in meta tags: ${result.description}`);
  }

  // Brand
  const brandMeta = document.querySelector(
    'meta[property="product:brand"], meta[property="og:brand"]'
  );
  debug.selector.check(
    'meta[property="product:brand"], meta[property="og:brand"]',
    brandMeta,
    "Brand"
  );

  if (brandMeta) {
    result.brand = brandMeta.getAttribute("content");
    debug.info(`Found brand in meta tags: ${result.brand}`);
  }

  // Availability
  const availabilityMeta = document.querySelector(
    'meta[property="product:availability"]'
  );
  debug.selector.check(
    'meta[property="product:availability"]',
    availabilityMeta,
    "Availability"
  );

  if (availabilityMeta) {
    result.availability = formatAvailability(
      availabilityMeta.getAttribute("content")
    );
    debug.info(`Found availability in meta tags: ${result.availability}`);
  }

  // Check if we have the minimum required info
  if (result.title && result.price) {
    result.success = true;
    debug.success("Successfully extracted product data from meta tags", result);
  } else {
    debug.info("Insufficient product data from meta tags", result);
  }

  debug.timing.end("Meta Tags Extraction", metaTagsTimer);
  return result;
}

/**
 * Extract product info using common DOM selectors
 */
function extractFromCommonSelectors() {
  const commonSelectorsTimer = debug.timing.start(
    "Common Selectors Extraction"
  );

  debug.info("Attempting extraction from common DOM selectors");

  const result = {
    title: null,
    price: null,
    originalPrice: null,
    currency: null,
    imageUrl: null,
    description: null,
    sku: null,
    availability: null,
    brand: null,
    success: false,
  };

  // Title selectors (optimized for e-commerce sites)
  const titleSelectors = [
    "h1.product-title",
    "h1.product-name",
    ".product-title h1",
    ".product-info h1",
    ".product-single__title",
    ".product-name h1",
    "#productTitle",
    ".product_title",
    '[itemprop="name"]',
    ".product-detail-name",
    ".urun-adi",
    ".productName",
    // If all else fails, just the first h1 if there's only one
    "h1",
  ];

  // Price selectors (optimized for e-commerce sites)
  const priceSelectors = [
    ".price",
    ".product-price",
    ".price-sales",
    ".current-price",
    '[data-price-type="finalPrice"]',
    '[itemprop="price"]',
    ".price-box .price",
    ".price-current",
    ".offer-price",
    ".price-container",
    ".current",
    ".now",
    ".urun-fiyat",
    ".fiyat",
    ".indirimliFiyat",
    ".satisFiyat",
    ".product-price-tr",
    ".prc-dsc",
  ];

  // Original price selectors (for discounted items)
  const oldPriceSelectors = [
    ".old-price",
    ".original-price",
    ".regular-price",
    ".was-price",
    ".price-old",
    ".list-price",
    ".price-before-discount",
    ".compare-at-price",
    ".eski-fiyat",
    ".previous-price",
  ];

  // Image selectors
  const imageSelectors = [
    ".product-image img",
    ".product-single__image",
    ".product-gallery__image",
    '[itemprop="image"]',
    ".product-photo-container img",
    "#product-image",
    ".ProductItem__Image",
    ".gallery-image",
    ".urun-resim img",
    ".product-image-tr img",
    // Try the first large image in the product area
    ".product-detail img",
    ".product-main img",
    ".detail img",
  ];

  // Description selectors
  const descriptionSelectors = [
    ".product-description",
    ".description",
    '[itemprop="description"]',
    ".product-short-description",
    ".product-info__description",
    ".urun-aciklama",
    ".productDescription",
  ];

  // SKU selectors
  const skuSelectors = [
    '[itemprop="sku"]',
    ".sku",
    ".product-sku",
    ".product-meta__sku",
    ".urun-kod",
    ".productSku",
  ];

  // Availability selectors
  const availabilitySelectors = [
    '[itemprop="availability"]',
    ".stock-level",
    ".availability",
    ".product-stock",
    ".urun-stok",
    ".stock-status",
    ".in-stock",
    ".out-of-stock",
  ];

  // Brand selectors
  const brandSelectors = [
    '[itemprop="brand"]',
    ".brand",
    ".product-brand",
    ".product-meta__vendor",
    ".marka",
    ".productBrand",
  ];

  // Try to find title
  for (const selector of titleSelectors) {
    const element = document.querySelector(selector);
    debug.selector.check(selector, element, "Title");

    if (element && element.textContent.trim()) {
      result.title = element.textContent.trim();
      debug.info(`Found title using selector ${selector}: ${result.title}`);
      break;
    }
  }

  // Try to find price
  for (const selector of priceSelectors) {
    const elements = document.querySelectorAll(selector);
    debug.info(
      `Found ${elements.length} potential price elements with selector: ${selector}`
    );

    for (const element of elements) {
      if (element && element.textContent.trim()) {
        const text = element.textContent.trim();
        debug.info(`Checking price text: "${text}"`);

        const match = text.match(/([0-9]+[.,][0-9]+)/);
        if (match) {
          // Extract the price and try to determine currency
          let price = match[1].replace(/\./g, "").replace(",", ".");
          result.price = price;
          debug.info(`Extracted price value: ${result.price}`);

          // Try to determine currency
          if (text.includes("TL") || text.includes("₺")) {
            result.currency = "TRY";
          } else if (text.includes("$")) {
            result.currency = "USD";
          } else if (text.includes("€")) {
            result.currency = "EUR";
          } else if (text.includes("£")) {
            result.currency = "GBP";
          }

          debug.info(`Detected currency: ${result.currency}`);
          break;
        }
      }
    }
    if (result.price) break;
  }

  // Try to find original price (for discounted items)
  for (const selector of oldPriceSelectors) {
    const elements = document.querySelectorAll(selector);
    debug.info(
      `Found ${elements.length} potential original price elements with selector: ${selector}`
    );

    for (const element of elements) {
      if (element && element.textContent.trim()) {
        const text = element.textContent.trim();
        debug.info(`Checking original price text: "${text}"`);

        const match = text.match(/([0-9]+[.,][0-9]+)/);
        if (match) {
          // Extract the original price
          result.originalPrice = match[1].replace(/\./g, "").replace(",", ".");
          debug.info(`Extracted original price: ${result.originalPrice}`);
          break;
        }
      }
    }
    if (result.originalPrice) break;
  }

  // Try to find image
  for (const selector of imageSelectors) {
    const element = document.querySelector(selector);
    debug.selector.check(selector, element, "Image");

    if (
      element &&
      (element.getAttribute("src") || element.getAttribute("data-src"))
    ) {
      let src = element.getAttribute("src") || element.getAttribute("data-src");
      result.imageUrl = makeImageUrlAbsolute(src);
      debug.info(`Found image using selector ${selector}: ${result.imageUrl}`);
      break;
    }
  }

  // Try to find description
  for (const selector of descriptionSelectors) {
    const element = document.querySelector(selector);
    debug.selector.check(selector, element, "Description");

    if (element && element.textContent.trim()) {
      result.description = element.textContent.trim();
      debug.info(`Found description using selector ${selector}`);
      break;
    }
  }

  // Try to find SKU
  for (const selector of skuSelectors) {
    const element = document.querySelector(selector);
    debug.selector.check(selector, element, "SKU");

    if (element && element.textContent.trim()) {
      result.sku = element.textContent.trim();
      debug.info(`Found SKU using selector ${selector}: ${result.sku}`);
      break;
    }
  }

  // Try to find availability
  for (const selector of availabilitySelectors) {
    const element = document.querySelector(selector);
    debug.selector.check(selector, element, "Availability");

    if (element) {
      // Check both text content and attribute
      const availText = element.textContent.trim();
      if (availText) {
        result.availability = availText;
        debug.info(`Found availability text: ${availText}`);
      } else {
        // Check for schema.org value in the content attribute
        const availAttr = element.getAttribute("content");
        if (availAttr) {
          result.availability = formatAvailability(availAttr);
          debug.info(`Found availability attribute: ${availAttr}`);
        }
      }

      // Also look at class names for availability hints
      if (element.classList.contains("in-stock")) {
        result.availability = "In Stock";
        debug.info("Found 'in-stock' class indicator");
      } else if (element.classList.contains("out-of-stock")) {
        result.availability = "Out of Stock";
        debug.info("Found 'out-of-stock' class indicator");
      }

      break;
    }
  }

  // Try to find brand
  for (const selector of brandSelectors) {
    const element = document.querySelector(selector);
    debug.selector.check(selector, element, "Brand");

    if (element && element.textContent.trim()) {
      result.brand = element.textContent.trim();
      debug.info(`Found brand using selector ${selector}: ${result.brand}`);
      break;
    }
  }

  // Check if we have the minimum required info
  if (result.title && result.price) {
    result.success = true;
    debug.success(
      "Successfully extracted product data from common selectors",
      result
    );
  } else {
    debug.info("Insufficient product data from common selectors", {
      foundTitle: !!result.title,
      foundPrice: !!result.price,
    });
  }

  debug.timing.end("Common Selectors Extraction", commonSelectorsTimer);
  return result;
}

/**
 * Last resort method: scan the document content for likely product info
 */
function scanContentForProductInfo() {
  const contentScanTimer = debug.timing.start("Content Scanning");

  debug.info("Starting content scanning (last resort method)");

  const result = {
    title: null,
    price: null,
    originalPrice: null,
    currency: null,
    imageUrl: null,
    description: null,
    success: false,
  };

  // Get probable title (usually the first h1 on a product page)
  const h1 = document.querySelector("h1");
  debug.selector.check("h1", h1, "Content Scan - Title");

  if (h1 && h1.textContent.trim()) {
    result.title = h1.textContent.trim();
    debug.info(`Found title from h1: ${result.title}`);
  } else {
    // Fallback to title tag
    const titleTag = document.querySelector("title");
    debug.selector.check("title", titleTag, "Content Scan - Title Fallback");

    if (titleTag && titleTag.textContent.trim()) {
      result.title = titleTag.textContent.trim();
      debug.info(`Found title from title tag: ${result.title}`);
    }
  }

  // Scan for price patterns in text nodes
  debug.info("Scanning text nodes for price patterns");
  const priceRegex = /([0-9]+[.,][0-9]+)\s*(?:TL|₺|\$|€|£)/gi;
  const textNodes = [];

  // Function to collect all text nodes
  function collectTextNodes(node) {
    if (node.nodeType === Node.TEXT_NODE) {
      const text = node.textContent.trim();
      if (text && text.length > 0) {
        textNodes.push({
          node: node,
          text: text,
          parent: node.parentElement,
        });
      }
    } else {
      for (const child of node.childNodes) {
        collectTextNodes(child);
      }
    }
  }

  collectTextNodes(document.body);
  debug.info(`Found ${textNodes.length} text nodes to scan`);

  // Find all prices and select the most likely one
  const priceMatches = [];
  for (const textNode of textNodes) {
    const matches = [...textNode.text.matchAll(priceRegex)];
    for (const match of matches) {
      priceMatches.push({
        price: match[1],
        currency:
          match[0].includes("TL") || match[0].includes("₺")
            ? "TRY"
            : match[0].includes("$")
            ? "USD"
            : match[0].includes("€")
            ? "EUR"
            : match[0].includes("£")
            ? "GBP"
            : null,
        element: textNode.parent,
        text: match[0],
      });
    }
  }

  debug.info(
    `Found ${priceMatches.length} possible price matches`,
    priceMatches
  );

  // Try to find images that might be product images
  const largeImages = Array.from(document.querySelectorAll("img"))
    .filter((img) => {
      const rect = img.getBoundingClientRect();
      return rect.width > 200 && rect.height > 200;
    })
    .map((img) => img.src || img.getAttribute("data-src"))
    .filter((src) => src)
    .map((src) => makeImageUrlAbsolute(src));

  debug.info(
    `Found ${largeImages.length} possible product images`,
    largeImages
  );

  if (largeImages.length > 0) {
    result.imageUrl = largeImages[0];
    debug.info(`Selected primary image: ${result.imageUrl}`);
  }

  // Select most likely price (closest to product title or largest on page)
  if (priceMatches.length > 0) {
    // Default to first match
    let bestMatch = priceMatches[0];
    debug.info("Finding best price match from candidates");

    if (result.title) {
      // Try to find price closest to title
      const titleElement = document.querySelector("h1");
      if (titleElement) {
        debug.info("Looking for price closest to title element");
        const titleRect = titleElement.getBoundingClientRect();
        let closestDistance = Infinity;

        for (const match of priceMatches) {
          try {
            const rect = match.element.getBoundingClientRect();
            const distance = Math.sqrt(
              Math.pow(rect.top - titleRect.bottom, 2) +
                Math.pow(rect.left - titleRect.left, 2)
            );

            debug.info(
              `Price match distance: ${distance.toFixed(2)}px from title`,
              { price: match.price, text: match.text }
            );

            if (distance < closestDistance) {
              closestDistance = distance;
              bestMatch = match;
            }
          } catch (e) {
            debug.error("Error calculating distance to price element", e);
            // If getBoundingClientRect fails, continue
          }
        }
      }
    }

    result.price = bestMatch.price.replace(/\./g, "").replace(",", ".");
    result.currency = bestMatch.currency;
    debug.info(
      `Selected best price match: ${result.price} ${result.currency}`,
      bestMatch
    );

    // Try to find original price near the current price
    if (bestMatch.element) {
      debug.info("Looking for original price near current price");
      const nearbyText = bestMatch.element.innerText || "";
      const oldPriceMatch = nearbyText.match(/([0-9]+[.,][0-9]+)/g);
      if (oldPriceMatch && oldPriceMatch.length > 1) {
        // Find a price different from the current price
        for (const price of oldPriceMatch) {
          const cleanPrice = price.replace(/\./g, "").replace(",", ".");
          if (cleanPrice !== result.price) {
            result.originalPrice = cleanPrice;
            debug.info(`Found nearby original price: ${result.originalPrice}`);
            break;
          }
        }
      }
    }
  }

  // Check if we have the minimum required info
  if (result.title && result.price) {
    result.success = true;
    debug.success(
      "Successfully extracted product data from content scanning",
      result
    );
  } else {
    debug.info("Insufficient product data from content scanning", {
      foundTitle: !!result.title,
      foundPrice: !!result.price,
    });
  }

  debug.timing.end("Content Scanning", contentScanTimer);
  return result;
}

/**
 * Better handling of availability status
 */
function formatAvailability(availability) {
  if (!availability) return null;

  debug.info(`Formatting availability: ${availability}`);

  // Check for schema.org formats
  if (
    availability === "http://schema.org/InStock" ||
    availability === "https://schema.org/InStock"
  ) {
    return "In Stock";
  } else if (
    availability === "http://schema.org/OutOfStock" ||
    availability === "https://schema.org/OutOfStock"
  ) {
    return "Out of Stock";
  } else if (
    availability === "http://schema.org/LimitedAvailability" ||
    availability === "https://schema.org/LimitedAvailability"
  ) {
    return "Limited Availability";
  } else if (
    availability === "http://schema.org/PreOrder" ||
    availability === "https://schema.org/PreOrder"
  ) {
    return "Pre-Order";
  }

  return availability;
}

/**
 * Ensures image URLs are absolute
 */
function makeImageUrlAbsolute(imgSrc) {
  if (!imgSrc) return null;

  debug.info(`Making image URL absolute: ${imgSrc}`);

  // Already absolute URL
  if (imgSrc.startsWith("http") || imgSrc.startsWith("https")) {
    return imgSrc;
  }

  // Convert relative URLs to absolute
  if (imgSrc.startsWith("/")) {
    const absoluteUrl = window.location.origin + imgSrc;
    debug.info(`Converted to absolute URL: ${absoluteUrl}`);
    return absoluteUrl;
  } else {
    // Handle relative paths without leading slash
    const baseUrl = window.location.href.substring(
      0,
      window.location.href.lastIndexOf("/") + 1
    );
    const absoluteUrl = baseUrl + imgSrc;
    debug.info(`Converted to absolute URL: ${absoluteUrl}`);
    return absoluteUrl;
  }
}

/**
 * Improved variant extraction to avoid extracting country codes
 */

// Add this code to your product_detector.js file to improve size detection
// This should be added to or replace the existing generic size element detection code

// Enhanced size extraction function
function enhancedSizeDetection() {
  debug.info("Running enhanced size detection");
  const sizes = [];

  // Method 1: Look for size buttons on the page
  const sizeButtons = document.querySelectorAll(
    '.size-item, .size-button, .size-selector, [data-test="product-size-selector"] button'
  );
  debug.info(`Found ${sizeButtons.length} size buttons`);

  if (sizeButtons.length > 0) {
    for (const button of sizeButtons) {
      const sizeText = button.textContent.trim();
      if (sizeText && !sizeText.toLowerCase().includes("select size")) {
        sizes.push({
          text: sizeText,
          selected:
            button.classList.contains("selected") ||
            button.classList.contains("active") ||
            button.getAttribute("aria-selected") === "true",
          value: button.dataset.size || button.value,
        });
      }
    }
  }

  // Method 2: Look for size elements in a different format
  if (sizes.length === 0) {
    const sizeElements = Array.from(
      document.querySelectorAll("div, span, label, button")
    ).filter((el) => {
      const text = el.textContent.trim();
      // Match common size patterns: numeric sizes, EU/US sizes, or letter sizes
      return (
        (text.match(/^[0-9]+(\.[05])?$/) || // 5, 5.5, 6, etc.
          text.match(/^(XS|S|M|L|XL|XXL)$/) || // S, M, L, etc.
          text.match(/^(EU|US|UK)\s*[0-9]+$/) || // EU 38, US 8, etc.
          text.match(/^[0-9]+\s*(EU|US|UK)$/)) && // 38 EU, 8 US, etc.
        text.length < 8 && // Size text is usually short
        el.clientWidth < 80 && // Size elements are usually small
        el.clientHeight < 80 &&
        window.getComputedStyle(el).display !== "none"
      );
    });

    debug.info(
      `Found ${sizeElements.length} potential alternative size elements`
    );

    // For Stradivarius and similar sites - look for size wrapper with size items
    const strdiSizeItems = document.querySelectorAll(
      ".js-product-size .size-name"
    );
    if (strdiSizeItems.length > 0) {
      debug.info(`Found ${strdiSizeItems.length} Stradivarius size items`);
      for (const item of strdiSizeItems) {
        // Get the parent size item to check if it's selected
        const parentItem = item.closest(".size-item");
        const sizeText =
          item.getAttribute("data-text") || item.textContent.trim();

        if (sizeText) {
          sizes.push({
            text: sizeText,
            selected: parentItem
              ? parentItem.classList.contains("selected")
              : false,
            value: sizeText,
          });
        }
      }
    }

    // Add the generic size elements found
    if (sizeElements.length > 0 && sizes.length === 0) {
      for (const element of sizeElements) {
        sizes.push({
          text: element.textContent.trim(),
          selected:
            element.classList.contains("selected") ||
            element.classList.contains("active") ||
            element.getAttribute("aria-selected") === "true",
          value: element.dataset.size || element.dataset.value,
        });
      }
    }
  }

  // Method 3: Extract sizes from the DOM
  if (sizes.length === 0) {
    // For Stradivarius and similar sites - check for data in JavaScript objects
    const scripts = document.querySelectorAll("script:not([src])");
    for (const script of scripts) {
      if (
        script.textContent.includes("window.dataLayer") &&
        script.textContent.includes("productSizeAvailable")
      ) {
        try {
          const matches = script.textContent.match(
            /window\.dataLayer\s*=\s*(\[.*?\]);/s
          );
          if (matches && matches[1]) {
            const dataLayer = JSON.parse(matches[1]);
            for (const item of dataLayer) {
              if (item.productSizeAvailable) {
                debug.info(
                  `Found sizes in dataLayer: ${item.productSizeAvailable}`
                );
                const sizeList = item.productSizeAvailable.split(",");
                for (const size of sizeList) {
                  sizes.push({
                    text: size.trim(),
                    selected: false,
                    value: size.trim(),
                  });
                }
                break;
              }
            }
          }
        } catch (e) {
          debug.error(`Error parsing dataLayer: ${e}`);
        }
      }

      // Look for size data in an array or object in the script
      if (
        script.textContent.includes('"sizes":') ||
        script.textContent.includes("sizes:") ||
        script.textContent.includes("availableSizes")
      ) {
        try {
          const productDataMatch = script.textContent.match(
            /product\s*[:=]\s*({.*?})/s
          );
          if (productDataMatch) {
            try {
              // Try to parse and clean the JSON-like string
              let jsonStr = productDataMatch[1]
                .replace(/'/g, '"')
                .replace(/(\w+):/g, '"$1":');

              jsonStr = jsonStr.replace(/,(\s*[\]}])/g, "$1"); // Fix trailing commas

              const productData = JSON.parse(jsonStr);
              if (productData.sizes && Array.isArray(productData.sizes)) {
                debug.info(
                  `Found sizes in product data: ${productData.sizes.length} sizes`
                );
                for (const size of productData.sizes) {
                  if (typeof size === "string") {
                    sizes.push({
                      text: size,
                      selected: false,
                      value: size,
                    });
                  } else if (typeof size === "object" && size !== null) {
                    sizes.push({
                      text:
                        size.name ||
                        size.label ||
                        size.text ||
                        size.value ||
                        "",
                      selected: size.selected || false,
                      value: size.value || size.id || "",
                    });
                  }
                }
              }
            } catch (e) {
              debug.error(`Error parsing product data JSON: ${e}`);
            }
          }
        } catch (e) {
          debug.error(`Error processing script for sizes: ${e}`);
        }
      }
    }
  }

  // Return deduplicated results
  return deduplicateVariants(sizes);
}

// Make sure to find the sizes section in the product detection flow
// and add this function call to improve size detection:

// Add this to the extractVariantInfo function right after the "Trying generic size element detection" section:
/*
  if (variants.sizes.length === 0) {
    debug.info("Using enhanced size detection techniques");
    variants.sizes = enhancedSizeDetection();
    debug.info(`Enhanced detection found ${variants.sizes.length} sizes`);
  }
*/

function extractVariantInfo() {
  const variantTimer = debug.timing.start("Variant Extraction");

  debug.info("Extracting product variants");

  let variants = {
    colors: [],
    sizes: [],
    otherOptions: [],
  };

  // Helper function to extract option text and selected state
  function extractOptionInfo(element) {
    if (!element) return null;

    const text = element.textContent.trim();
    debug.info(`Examining variant option: "${text}"`);

    // Skip options that look like country codes with phone numbers
    if (text.match(/^\+\d+ [A-Za-z]/)) {
      debug.info(`Skipping option that looks like a country code: "${text}"`);
      return null;
    }

    // Skip generic placeholder text and customer information options
    const skipPatterns = [
      "select size",
      "select option",
      "availability",
      "mr.",
      "ms.",
      "mrs.",
      "miss",
      "dr.",
      "prof.",
      "i'd rather not say",
      "quality & characteristics",
      "select",
    ];

    const lowerText = text.toLowerCase();
    if (skipPatterns.some((pattern) => lowerText.includes(pattern))) {
      debug.info(`Skipping option with generic text: "${text}"`);
      return null;
    }

    let selected = false;

    // Check various indicators of selection
    if (
      element.hasAttribute("selected") ||
      element.hasAttribute("checked") ||
      element.classList.contains("selected") ||
      element.classList.contains("active") ||
      element.getAttribute("aria-selected") === "true"
    ) {
      selected = true;
      debug.info(`Option "${text}" is selected`);
    }

    // For color options, try to get the color value
    let colorValue = null;
    const bgColor = window.getComputedStyle(element).backgroundColor;
    if (
      bgColor &&
      bgColor !== "transparent" &&
      bgColor !== "rgba(0, 0, 0, 0)"
    ) {
      colorValue = bgColor;
      debug.info(`Found color value from background-color: ${colorValue}`);
    }

    // Try to get data-color attribute
    const dataColor =
      element.getAttribute("data-color") ||
      element.getAttribute("data-value") ||
      element.getAttribute("data-option-value");
    if (dataColor) {
      colorValue = dataColor;
      debug.info(`Found color value from data attribute: ${colorValue}`);
    }

    // Check for style attribute with background-color
    const style = element.getAttribute("style");
    if (style && style.includes("background-color")) {
      const match = style.match(/background-color:\s*([^;]+)/i);
      if (match) {
        colorValue = match[1];
        debug.info(`Found color value from style attribute: ${colorValue}`);
      }
    }

    // Check for an img child that might represent the color
    const colorImg = element.querySelector("img");
    if (colorImg) {
      const imgSrc = colorImg.getAttribute("src");
      if (imgSrc) {
        // Convert relative URLs to absolute
        let absoluteImgSrc = imgSrc;
        if (imgSrc.startsWith("/")) {
          absoluteImgSrc = window.location.origin + imgSrc;
        } else if (!imgSrc.startsWith("http")) {
          const baseUrl = window.location.href.substring(
            0,
            window.location.href.lastIndexOf("/") + 1
          );
          absoluteImgSrc = baseUrl + imgSrc;
        }
        colorValue = absoluteImgSrc;
        debug.info(`Found color value from image: ${colorValue}`);
      }
    }

    const result = {
      text: text,
      selected: selected,
      value: colorValue,
    };

    debug.data.extracted("variant option", result);
    return result;
  }

  // 1. Try to find color options
  const colorSelectors = [
    ".color-option",
    ".color-selector",
    ".color-swatch",
    ".color-select",
    ".color-radio",
    ".color-box",
    '[data-option-type="color"]',
    '[data-attribute="color"]',
    ".js-color-variant",
    ".color-tiles",
    ".color-squares",
    // Turkish-specific selectors
    ".renk-secimi",
    ".renk-secenekleri",
    ".renk-kutusu",
  ];

  debug.info("Searching for color variants");
  for (const selector of colorSelectors) {
    const elements = document.querySelectorAll(selector);
    debug.selector.check(
      selector,
      elements.length > 0 ? elements[0] : null,
      "Color Variant"
    );

    if (elements && elements.length > 0) {
      debug.info(
        `Found ${elements.length} color options with selector: ${selector}`
      );

      for (const element of elements) {
        const info = extractOptionInfo(element);
        if (info) variants.colors.push(info);
      }
      break;
    }
  }

  // 2. Try to find size options
  const sizeSelectors = [
    ".sizes-list .size-item",
    ".size-name[data-text]",
    "[data-testid='size-item']",
    "[data-testid='sizes-list']",
    ".size-option",
    ".size-selector",
    ".size-swatch",
    ".size-select",
    ".size-radio",
    ".size-box",
    '[data-option-type="size"]',
    '[data-attribute="size"]',
    ".js-size-variant",
    ".size-tiles",
    ".size-squares",
    // Turkish-specific selectors
    ".beden-secimi",
    ".beden-secenekleri",
    ".olcu-kutusu",
  ];

  debug.info("Searching for size variants");
  for (const selector of sizeSelectors) {
    const elements = document.querySelectorAll(selector);
    debug.selector.check(
      selector,
      elements.length > 0 ? elements[0] : null,
      "Size Variant"
    );

    if (elements && elements.length > 0) {
      debug.info(
        `Found ${elements.length} size options with selector: ${selector}`
      );

      for (const element of elements) {
        const info = extractOptionInfo(element);
        if (info) variants.sizes.push(info);
      }
      break;
    }
  }

  // 3. Look for select elements that might contain variants
  debug.info("Searching for variants in select elements");
  const selectElements = document.querySelectorAll("select");
  debug.info(`Found ${selectElements.length} select elements to examine`);

  for (const select of selectElements) {
    // Try to determine what type of variant this is
    const labelElement = document.querySelector(`label[for="${select.id}"]`);
    const labelText = labelElement
      ? labelElement.textContent.toLowerCase().trim()
      : "";
    const selectName = select.getAttribute("name")
      ? select.getAttribute("name").toLowerCase()
      : "";

    debug.info(
      `Examining select element: ${selectName || select.id || "unnamed"}`,
      { label: labelText, name: selectName }
    );

    // Skip form fields that might be for customer information
    if (
      labelText.includes("country") ||
      labelText.includes("phone") ||
      labelText.includes("address") ||
      labelText.includes("title") ||
      labelText.includes("salutation") ||
      labelText.includes("gender") ||
      labelText.includes("options") ||
      labelText.includes("quality") ||
      labelText.includes("characteristics") ||
      selectName.includes("country") ||
      selectName.includes("phone") ||
      selectName.includes("address") ||
      selectName.includes("title") ||
      selectName.includes("salutation") ||
      selectName.includes("gender") ||
      selectName.includes("options") ||
      selectName.includes("quality") ||
      selectName.includes("characteristics")
    ) {
      debug.info(
        `Skipping select that appears to be for customer information: ${
          labelText || selectName
        }`
      );
      continue;
    }

    // Decide which variant category this belongs to
    let variantType = "otherOptions";
    if (
      labelText.includes("color") ||
      labelText.includes("colour") ||
      labelText.includes("renk") ||
      selectName.includes("color") ||
      selectName.includes("colour") ||
      selectName.includes("renk")
    ) {
      variantType = "colors";
      debug.info(`Identified as color select`);
    } else if (
      labelText.includes("size") ||
      labelText.includes("beden") ||
      selectName.includes("size") ||
      selectName.includes("beden")
    ) {
      variantType = "sizes";
      debug.info(`Identified as size select`);
    } else {
      debug.info(`Identified as other option type`);
    }

    // Extract options from this select
    const options = select.querySelectorAll("option");
    debug.info(`Found ${options.length} options in this select`);

    for (const option of options) {
      if (!option.value || option.value === "") {
        debug.info(`Skipping empty option value`);
        continue;
      }

      const info = extractOptionInfo(option);
      if (info) variants[variantType].push(info);
    }
  }

  // 4. Find other common variant selectors (radio buttons, etc.)
  const otherVariantSelectors = [
    ".js-option-selector",
    ".variant-option",
    ".variant-select",
    ".product-form__option",
    ".option-value",
    ".option-selector",
    // Turkish-specific selectors
    ".urun-secenek",
    ".varyasyon-secimi",
  ];

  debug.info("Searching for other variant types");
  for (const selector of otherVariantSelectors) {
    const elements = document.querySelectorAll(selector);
    debug.selector.check(
      selector,
      elements.length > 0 ? elements[0] : null,
      "Other Variant"
    );

    if (elements && elements.length > 0) {
      debug.info(
        `Found ${elements.length} other options with selector: ${selector}`
      );

      for (const element of elements) {
        const info = extractOptionInfo(element);
        if (info) variants.otherOptions.push(info);
      }
    }
  }

  // Log summary of found variants
  debug.info("Variant extraction complete", {
    colors: variants.colors.length,
    sizes: variants.sizes.length,
    otherOptions: variants.otherOptions.length,
  });

  debug.timing.end("Variant Extraction", variantTimer);
  function deduplicateVariants(variantArray) {
    const uniqueMap = new Map();

    // Prioritize selected variants
    variantArray.forEach((variant) => {
      const existingVariant = uniqueMap.get(variant.text);
      // If this variant is selected or there's no existing variant with this text, use it
      if (variant.selected || !existingVariant) {
        uniqueMap.set(variant.text, variant);
      }
    });

    return Array.from(uniqueMap.values());
  }

  // Apply deduplication to all variant types
  if (variants.colors.length > 0) {
    variants.colors = deduplicateVariants(variants.colors);
  }
  if (variants.sizes.length > 0) {
    variants.sizes = deduplicateVariants(variants.sizes);
  }
  if (variants.otherOptions.length > 0) {
    variants.otherOptions = deduplicateVariants(variants.otherOptions);
  }

  debug.info("After deduplication, variant counts:", {
    colors: variants.colors.length,
    sizes: variants.sizes.length,
    otherOptions: variants.otherOptions.length,
  });
  const sizeContainerSelectors = [
    ".size-container",
    ".sizes",
    ".product-sizes",
    ".size-options",
    ".size-selection",
    ".product-size-selector",
    ".size-picker",
    '[data-component="sizes"]',
    '[data-test="size-selector"]',
    // Italian/Luxury specific
    ".taglia",
    ".taglie",
    ".size-guide",
    ".product-variants",
  ];

  for (const selector of sizeContainerSelectors) {
    const container = document.querySelector(selector);
    if (container) {
      // Look for clickable elements within the container
      const sizeElements = container.querySelectorAll(
        'button, li, div[role="button"], a[role="button"], span[data-value]'
      );

      for (const element of sizeElements) {
        // Check if this looks like a size element
        const text = element.textContent.trim();
        // Filter out noise ("size guide", "size chart", etc.)
        if (text && !text.match(/guide|chart|info|view|close|select/i)) {
          variants.sizes.push({
            text: text,
            selected:
              element.classList.contains("selected") ||
              element.getAttribute("aria-selected") === "true" ||
              element.classList.contains("active"),
            value:
              element.getAttribute("data-value") ||
              element.getAttribute("data-size"),
          });
        }
      }

      if (variants.sizes.length > 0) {
        break; // Found sizes, no need to check other selectors
      }
    }
  }

  // Method 3: Look for size data in scripts
  if (variants.sizes.length === 0) {
    debug.info(
      "No size variants found with standard methods, trying luxury retailer patterns"
    );

    // 1. Look for specialized size containers common in luxury sites
    const luxurySizeSelectors = [
      ".sizes-list", // Add this for Stradivarius
      ".sizes-list .size-item", // Add this for Stradivarius
      // Gucci specific selectors
      ".product__options-container",
      ".product__size-selector",
      ".pdp__size-selector",
      ".product-detail__size-selector",
      ".size-selector__options",
      ".product-size-selector",
      ".product-sizes",
      ".pdp-sizes",
      // Italian luxury common patterns
      ".size-dropdown",
      ".size-options",
      ".size-picker",
      '[data-test="product-size-selector"]',
      '[data-component="SizeSelector"]',
      '[aria-label="size selector"]',
      '[data-element-id="size-selector"]',
    ];

    for (const selector of luxurySizeSelectors) {
      const container = document.querySelector(selector);
      debug.info(
        `Checking luxury size container: ${selector} - ${
          container ? "Found" : "Not found"
        }`
      );

      if (container) {
        // Look for size elements within the container - find any clickable elements
        if (container.classList.contains("sizes-list")) {
          const sizeItems = container.querySelectorAll(".size-item");
          for (const item of sizeItems) {
            const sizeElement = item.querySelector(".size-name");
            if (sizeElement) {
              const sizeText =
                sizeElement.getAttribute("data-text") ||
                sizeElement.textContent.trim();
              const isSelected = item.classList.contains("selected");
              const isAvailable = !item.classList.contains("disabled");

              variants.sizes.push({
                text: sizeText,
                selected: isSelected,
                value: sizeText,
                available: isAvailable,
              });
            }
          }
        }
        const sizeElements = container.querySelectorAll(
          'button, li, span[role="button"], div[role="option"], div[data-test-id*="size"], div[data-size]'
        );
        debug.info(
          `Found ${sizeElements.length} potential size elements in container`
        );

        for (const element of sizeElements) {
          const text = element.textContent.trim();
          // Skip non-size elements like headers, guides, etc.
          if (
            text &&
            !text.match(/size guide|chart|view all|select size|size:/i)
          ) {
            debug.info(`Found potential size option: ${text}`);
            variants.sizes.push({
              text: text,
              selected:
                element.classList.contains("selected") ||
                element.classList.contains("active") ||
                element.getAttribute("aria-selected") === "true" ||
                element.getAttribute("data-selected") === "true",
              value:
                element.getAttribute("data-size") ||
                element.getAttribute("data-value"),
            });
          }
        }

        if (variants.sizes.length > 0) {
          debug.success(
            `Found ${variants.sizes.length} size options in luxury container`
          );
          break;
        }
      }
    }
  }

  // 2. If still no sizes, try extracting from JavaScript data in the page
  if (variants.sizes.length === 0) {
    debug.info("Trying to extract size data from JavaScript variables");

    // Look for inline scripts that might contain product data
    const scripts = document.querySelectorAll("script:not([src])");

    for (const script of scripts) {
      const content = script.textContent;

      // Look for common patterns in JS object declarations
      if (
        content.includes('"sizes":') ||
        content.includes('"variants":') ||
        content.includes("sizes:") ||
        content.includes("variants:")
      ) {
        try {
          // Try to extract JSON-like structures
          const sizeMatches =
            content.match(/["']sizes["']\s*:\s*(\[.*?\])/s) ||
            content.match(/sizes\s*:\s*(\[.*?\])/s);

          if (sizeMatches && sizeMatches[1]) {
            // Convert to valid JSON by replacing single quotes and fixing unquoted keys
            let jsonStr = sizeMatches[1]
              .replace(/'/g, '"')
              .replace(/(\w+):/g, '"$1":');

            try {
              const sizeData = JSON.parse(jsonStr);
              debug.info(`Found size data in script: ${sizeData.length} items`);

              // Process the extracted size data
              for (const size of sizeData) {
                // Handle different possible structures
                if (typeof size === "string") {
                  variants.sizes.push({
                    text: size,
                    selected: false,
                    value: size,
                  });
                } else if (typeof size === "object") {
                  // Extract size info from object
                  const text =
                    size.name || size.label || size.value || size.size || "";
                  if (text) {
                    variants.sizes.push({
                      text: text,
                      selected: size.selected || size.isSelected || false,
                      value: size.value || size.id || text,
                    });
                  }
                }
              }
            } catch (e) {
              debug.error(`Error parsing size JSON: ${e.message}`);
            }
          }
        } catch (e) {
          debug.error(`Error processing script content: ${e.message}`);
        }
      }

      if (variants.sizes.length > 0) break;
    }
  }

  // 3. Last resort: Look for any element that resembles a size option
  if (variants.sizes.length === 0) {
    debug.info("Trying generic size element detection");

    // Look for elements that match size patterns (like EU sizes, US sizes, etc.)
    const sizePatternElements = Array.from(
      document.querySelectorAll("div, span, button, li")
    ).filter((el) => {
      const text = el.textContent.trim();
      // Match common size patterns: EU 40, 10.5, XXL, 42 IT, etc.
      return (
        text.match(
          /^(XS|S|M|L|XL|XXL|XXXL|[0-9]+(\.[05])?|EU\s*[0-9]+|[0-9]+\s*IT|IT\s*[0-9]+)$/i
        ) &&
        text.length < 10 && // Size text is usually short
        el.getBoundingClientRect().width < 100
      ); // Size elements are usually small
    });

    debug.info(
      `Found ${sizePatternElements.length} potential generic size elements`
    );
    if (variants.sizes.length === 0) {
      debug.info("Using enhanced size detection techniques");
      variants.sizes = enhancedSizeDetection();
      debug.info(`Enhanced detection found ${variants.sizes.length} sizes`);
    }

    for (const element of sizePatternElements) {
      variants.sizes.push({
        text: element.textContent.trim(),
        selected:
          element.classList.contains("selected") ||
          element.classList.contains("active") ||
          element.getAttribute("aria-selected") === "true",
        value:
          element.getAttribute("data-value") ||
          element.getAttribute("data-size"),
      });
    }
  }

  // Deduplicate variants (same as before)
  function deduplicateVariants(variantArray) {
    const uniqueMap = new Map();

    // Prioritize selected variants
    variantArray.forEach((variant) => {
      const existingVariant = uniqueMap.get(variant.text);
      if (variant.selected || !existingVariant) {
        uniqueMap.set(variant.text, variant);
      }
    });

    return Array.from(uniqueMap.values());
  }

  if (variants.colors.length > 0) {
    variants.colors = deduplicateVariants(variants.colors);
  }
  if (variants.sizes.length > 0) {
    variants.sizes = deduplicateVariants(variants.sizes);
  }
  if (variants.otherOptions.length > 0) {
    variants.otherOptions = deduplicateVariants(variants.otherOptions);
  }
  if (variants.sizes.length === 0) {
    debug.info("Trying to extract sizes from Select2 components");

    // Check for Select2 containers or Gucci's custom selectors
    const select2Containers = document.querySelectorAll(
      ".select2-container, .select2-selection, .custom-select-size, " +
        '[id*="select2"], [aria-labelledby*="select2"], [aria-owns*="select2"]'
    );

    if (select2Containers.length > 0) {
      debug.info(
        `Found ${select2Containers.length} potential Select2 containers`
      );

      // Look specifically for Gucci's pattern
      const gucciSizeSelect = document.querySelector(
        '.custom-select-size, [aria-labelledby="select2-pdp-size-selector-container"]'
      );

      if (gucciSizeSelect) {
        debug.info("Found Gucci Select2 size container");

        // 1. Check for currently selected size
        const selectedContent = gucciSizeSelect.querySelector(
          ".custom-select-content-size, .select2-selection__rendered"
        );
        if (
          selectedContent &&
          !selectedContent.textContent.toLowerCase().includes("select size")
        ) {
          const sizeText = selectedContent.textContent.trim();
          debug.info(`Found selected size: ${sizeText}`);
          variants.sizes.push({
            text: sizeText,
            selected: true,
            value: sizeText,
          });
        }

        // 2. Look for the dropdown container referenced by aria attributes
        const dropdownId =
          gucciSizeSelect.getAttribute("aria-owns") ||
          gucciSizeSelect.getAttribute("aria-controls");

        if (dropdownId) {
          const dropdown = document.getElementById(dropdownId);
          if (dropdown) {
            debug.info(`Found Select2 dropdown with ID: ${dropdownId}`);
            const sizeOptions = dropdown.querySelectorAll(
              "li, .select2-results__option"
            );

            for (const option of sizeOptions) {
              const text = option.textContent.trim();
              if (text && !text.toLowerCase().includes("select size")) {
                debug.info(`Found size option: ${text}`);
                variants.sizes.push({
                  text: text,
                  selected: option.classList.contains(
                    "select2-results__option--highlighted"
                  ),
                  value: option.getAttribute("id") || text,
                });
              }
            }
          }
        }
      }
    }

    // If still no sizes, try to find the sizes in the page source
    if (
      variants.sizes.length === 0 &&
      window.location.href.includes("gucci.com")
    ) {
      debug.info("Trying to extract Gucci sizes from page source");

      // Specifically for Gucci, look for characteristic size pattern
      const sizePatternsGucci = [
        /\d{2}(\.\d)?\s*IT/i, // e.g., "34 IT", "34.5 IT"
        /IT\s*\d{2}(\.\d)?/i, // e.g., "IT 34", "IT 34.5"
        /EU\s*\d{2}(\.\d)?/i, // e.g., "EU 34", "EU 34.5"
        /\d{2}(\.\d)?\s*EU/i, // e.g., "34 EU", "34.5 EU"
      ];

      // Look through all text nodes for these patterns
      const allTextNodes = [];
      const walker = document.createTreeWalker(
        document.body,
        NodeFilter.SHOW_TEXT,
        null,
        false
      );

      let node;
      while ((node = walker.nextNode())) {
        const text = node.textContent.trim();
        if (text.length > 0 && text.length < 10) {
          // Size text is typically short
          for (const pattern of sizePatternsGucci) {
            if (pattern.test(text)) {
              debug.info(`Found text matching Gucci size pattern: ${text}`);
              allTextNodes.push({
                text: text,
                node: node,
              });
              break;
            }
          }
        }
      }

      // Look for clustered size text nodes (likely size options)
      if (allTextNodes.length > 0) {
        debug.info(
          `Found ${allTextNodes.length} potential Gucci size text nodes`
        );

        // Add them as size options
        for (const item of allTextNodes) {
          // Check if this text node is in a presentational element (not hidden/utility)
          const parent = item.node.parentElement;
          if (
            parent &&
            getComputedStyle(parent).display !== "none" &&
            !parent.classList.contains("hidden") &&
            parent.getBoundingClientRect().width > 0
          ) {
            variants.sizes.push({
              text: item.text,
              selected: false,
              value: item.text,
            });
          }
        }
      }

      // Look for JavaScript variables with size data
      const scripts = document.querySelectorAll("script:not([src])");
      for (const script of scripts) {
        if (
          script.textContent.includes("pdpSizes") ||
          script.textContent.includes("availableSizes") ||
          script.textContent.includes("sizesAvailable")
        ) {
          try {
            // Use regex to find size arrays
            const sizeArrayMatch =
              script.textContent.match(/pdpSizes\s*=\s*(\[.*?\])/s) ||
              script.textContent.match(/availableSizes\s*=\s*(\[.*?\])/s) ||
              script.textContent.match(/sizesAvailable\s*=\s*(\[.*?\])/s);

            if (sizeArrayMatch && sizeArrayMatch[1]) {
              // Try to convert to valid JSON
              let jsonStr = sizeArrayMatch[1]
                .replace(/'/g, '"')
                .replace(/(\w+):/g, '"$1":');

              try {
                const sizeData = JSON.parse(jsonStr);
                debug.info(`Found ${sizeData.length} sizes in JavaScript data`);

                for (const size of sizeData) {
                  if (typeof size === "string") {
                    variants.sizes.push({
                      text: size,
                      selected: false,
                      value: size,
                    });
                  } else if (typeof size === "object") {
                    const text = size.label || size.name || size.size || "";
                    if (text) {
                      variants.sizes.push({
                        text: text,
                        selected: false,
                        value: size.value || size.id || text,
                      });
                    }
                  }
                }
              } catch (e) {
                debug.error(`Error parsing size JSON: ${e.message}`);
              }
            }
          } catch (e) {
            debug.error(`Error processing Gucci script content: ${e.message}`);
          }
        }
      }
    }
  }

  debug.info("Variant extraction complete", {
    colors: variants.colors.length,
    sizes: variants.sizes.length,
    otherOptions: variants.otherOptions.length,
  });

  debug.timing.end("Variant Extraction", variantTimer);
  return variants;
}
