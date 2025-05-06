/**
 * Enhanced Product Detector Script for E-commerce Websites
 *
 * This script detects product information from various e-commerce websites
 * and sends it back to the Flutter app via FlutterChannel.
 *
 * Features:
 * - Generic detection for common e-commerce patterns
 * - Platform-specific extractors (Shopify, WooCommerce, etc.)
 * - Site-specific extractors (Gucci, etc.)
 * - Robust retry and error handling
 */

// ==================== Configuration ====================
const CONFIG = {
  // Core settings
  initialDelay: 800, // Initial detection delay after page load (ms)
  maxRetries: 3, // Maximum number of retry attempts
  retryDelay: 1000, // Delay between retries (ms)
  observerDebounceTime: 300, // Time to wait after DOM changes before re-checking (ms)

  // Extraction settings
  minImageSize: 150, // Minimum size (width/height) for product images
  preferredImageSize: 400, // Preferred minimum size for product images

  // Logging
  debug: true, // Enable or disable debug logging
  debugTag: "PD", // Tag for filtering logs
};

// ==================== Utilities ====================

// Enhanced logging utility with consistent formatting and filtering
const Logger = {
  // Log levels
  levels: {
    DEBUG: 0,
    INFO: 1,
    WARN: 2,
    ERROR: 3,
  },

  currentLevel: 0, // Default to DEBUG

  // Main logging method
  log: function (level, message, data = null) {
    if (!CONFIG.debug || level < this.currentLevel) return;

    const timestamp = new Date().toISOString().slice(11, 23); // HH:MM:SS.mmm
    const prefix = `[${timestamp}][${CONFIG.debugTag}]`;

    let levelName;
    switch (level) {
      case this.levels.DEBUG:
        levelName = "DEBUG";
        break;
      case this.levels.INFO:
        levelName = "INFO";
        break;
      case this.levels.WARN:
        levelName = "WARN";
        break;
      case this.levels.ERROR:
        levelName = "ERROR";
        break;
      default:
        levelName = "UNKNOWN";
    }

    const logPrefix = `${prefix}[${levelName}]`;

    if (data !== null) {
      console.log(`${logPrefix} ${message}`, data);
    } else {
      console.log(`${logPrefix} ${message}`);
    }
  },

  // Convenience methods
  debug: function (message, data = null) {
    this.log(this.levels.DEBUG, message, data);
  },

  info: function (message, data = null) {
    this.log(this.levels.INFO, message, data);
  },

  warn: function (message, data = null) {
    this.log(this.levels.WARN, message, data);
  },

  error: function (message, data = null) {
    this.log(this.levels.ERROR, message, data);
  },
};

// DOM helper utilities
const DOMUtils = {
  // Try multiple selectors, return the first matching element
  querySelector: function (selectors) {
    for (const selector of selectors) {
      try {
        const element = document.querySelector(selector);
        if (element) return element;
      } catch (e) {
        // Invalid selector, try next one
      }
    }
    return null;
  },

  // Try multiple selectors, return all matching elements from the first selector that matches
  querySelectorAll: function (selectors) {
    for (const selector of selectors) {
      try {
        const elements = document.querySelectorAll(selector);
        if (elements && elements.length > 0) return elements;
      } catch (e) {
        // Invalid selector, try next one
      }
    }
    return [];
  },

  // Get text content from element with fallback
  getTextContent: function (element) {
    if (!element) return "";
    return (element.textContent || "").trim();
  },

  // Get attribute with fallback
  getAttribute: function (element, attr, defaultValue = "") {
    if (!element) return defaultValue;
    const value = element.getAttribute(attr);
    return value !== null ? value : defaultValue;
  },

  // Get computed style property with fallback
  getStyle: function (element, property, defaultValue = "") {
    if (!element) return defaultValue;
    try {
      return window.getComputedStyle(element)[property] || defaultValue;
    } catch (e) {
      return defaultValue;
    }
  },

  // Check if element is visible
  isVisible: function (element) {
    if (!element) return false;

    const style = window.getComputedStyle(element);
    return (
      style.display !== "none" &&
      style.visibility !== "hidden" &&
      style.opacity !== "0" &&
      element.offsetWidth > 0 &&
      element.offsetHeight > 0
    );
  },

  // Find the largest visible image
  findLargestImage: function () {
    const images = document.querySelectorAll("img");
    let bestImage = null;
    let largestArea = 0;

    for (const img of images) {
      if (!this.isVisible(img)) continue;

      const rect = img.getBoundingClientRect();
      const area = rect.width * rect.height;

      if (
        area > largestArea &&
        rect.width >= CONFIG.minImageSize &&
        rect.height >= CONFIG.minImageSize
      ) {
        // Prefer images above a certain size
        const isPreferredSize =
          rect.width >= CONFIG.preferredImageSize &&
          rect.height >= CONFIG.preferredImageSize;

        // Only replace if new image is preferred size or current best is not
        if (
          isPreferredSize ||
          largestArea < CONFIG.preferredImageSize * CONFIG.preferredImageSize
        ) {
          largestArea = area;
          bestImage = img;
        }
      }
    }

    return bestImage;
  },
};

// String and data formatting utilities
const FormatUtils = {
  // Convert relative URL to absolute
  makeUrlAbsolute: function (url) {
    if (!url) return null;

    // Already absolute
    if (url.startsWith("http")) return url;

    // Handle protocol-relative URLs - this is the key fix for Gucci
    if (url.startsWith("//")) {
      return "https:" + url;
    }

    // Handle root-relative URLs
    if (url.startsWith("/")) {
      return window.location.origin + url;
    }

    // Handle relative URLs
    const base = window.location.href.substring(
      0,
      window.location.href.lastIndexOf("/") + 1
    );
    return base + url;
  },

  // Format price string to numeric value
  formatPrice: function (priceStr) {
    if (!priceStr) return null;

    // Remove all non-numeric characters except . and ,
    let price = priceStr.replace(/[^\d.,]/g, "");

    // Handle European style numbers (1.234,56 -> 1234.56)
    if (price.includes(",") && price.includes(".")) {
      // Remove all periods (thousand separators in European format)
      price = price.replace(/\./g, "");
      // Replace comma with period (decimal separator)
      price = price.replace(",", ".");
    } else if (price.includes(",")) {
      // If only comma exists, it's likely a decimal separator
      price = price.replace(",", ".");
    }

    const numericPrice = parseFloat(price);
    return isNaN(numericPrice) ? null : numericPrice;
  },

  // Detect currency from price string
  detectCurrency: function (priceStr) {
    if (!priceStr) return null;

    const currencies = {
      $: "USD",
      "€": "EUR",
      "£": "GBP",
      "¥": "JPY",
      "₹": "INR",
      "₽": "RUB",
      "₺": "TRY",
      kr: "SEK", // Also NOK, DKK
      R$: "BRL",
      C$: "CAD",
      A$: "AUD",
      HK$: "HKD",
      zł: "PLN",
      CHF: "CHF",
      Kč: "CZK",
      RUB: "RUB",
      TL: "TRY",
      USD: "USD",
      EUR: "EUR",
      GBP: "GBP",
    };

    for (const symbol in currencies) {
      if (priceStr.includes(symbol)) {
        return currencies[symbol];
      }
    }

    // Default to USD if we can't detect
    return "USD";
  },

  // Clean and normalize text
  cleanText: function (text) {
    if (!text) return "";

    // Remove extra whitespace
    return text.replace(/\s+/g, " ").trim();
  },
};

// ==================== Product Page Detection ====================

// Detect if current page is a product page
const ProductPageDetector = {
  // Check URL patterns common for product pages
  checkURL: function () {
    const url = window.location.href;
    
    // Check if it's Pandora website
    if (url.includes("pandora.net")) {
      // Pandora product URLs have numeric/alphanumeric product codes ending with .html
      // Examples: 198421C01.html, A009.html, 568707C00.html
      const pandoraProductPattern = /pandora\.net\/.*\/.*\/[A-Z0-9]+\.html/;
      
      // Skip homepage and category pages
      const pandoraNonProductPattern = /pandora\.net\/[a-z-]+\/?$/;
      
      if (pandoraProductPattern.test(url)) {
        Logger.info(`Pandora product URL detected: ${url}`);
        return true;
      } else if (pandoraNonProductPattern.test(url)) {
        Logger.info(`Pandora non-product page detected: ${url}`);
        return false;
      }
      
      // For other Pandora pages, fall back to standard detection methods
      return false;
    }
    
    // Check if it's Guess website
    if (url.includes("guess.eu")) {
      // Guess product URLs have specific pattern with .html extension
      // Example: https://www.guess.eu/en-tr/guess/women/bags/handbags/helina-pochette-handbag-pink/HWBG9640750-ORC.html
      const guessProductPattern = /guess\.eu\/.*\/.*\.html$/;
      
      // Skip homepage and category pages
      const guessNonProductPattern = /guess\.eu\/.*\/(home|men|women|new-in|sale|accessories|clothing|bags|shoes|watches|jewelry)(\?.*)?$/;
      
      if (guessProductPattern.test(url)) {
        Logger.info(`Guess product URL detected: ${url}`);
        return true;
      } else if (guessNonProductPattern.test(url)) {
        Logger.info(`Guess non-product page detected: ${url}`);
        return false;
      }
      
      // For other Guess pages, fall back to standard detection methods
      return false;
    }
    
    // Check if it's Swarovski website
    if (url.includes("swarovski.com")) {
      // Swarovski product URLs have /p-XXXXXXX/ pattern in them
      // Example: https://www.swarovski.com/en-TR/p-M5720860/Ariana-Grande-x-Swarovski-Tennis-bracelet-Mixed-cuts-Heart-White-Rhodium-plated/
      const swarovskiProductPattern = /swarovski\.com\/.*\/p-[A-Za-z0-9]+\//;
      
      // Skip homepage and category pages
      const swarovskiNonProductPattern = /swarovski\.com\/[a-z-]+\/?$/;
      
      if (swarovskiProductPattern.test(url)) {
        Logger.info(`Swarovski product URL detected: ${url}`);
        return true;
      } else if (swarovskiNonProductPattern.test(url)) {
        Logger.info(`Swarovski non-product page detected: ${url}`);
        return false;
      }
      
      // For other Swarovski pages, fall back to standard detection methods
      return false;
    }
    
    // Check if it's Cartier website
    if (url.includes("cartier.com")) {
      // For Cartier, only detect product pages with specific URL pattern
      // Example: https://www.cartier.com/en-tr/jewellery/bracelets/juste-un-clou-bracelet-small-model-B6062617.html
      // Cartier product URLs end with a product code like B6062617.html or CRWGSA0096.html
      const cartierProductPattern = /cartier\.com\/.*\/.*\/.*-[A-Z0-9]+\.html$/;
      
      // Skip category pages
      const cartierCategoryPattern = /cartier\.com\/.*\/.*\/collections\//;
      
      if (cartierProductPattern.test(url)) {
        Logger.info(`Cartier product URL detected: ${url}`);
        return true;
      } else if (cartierCategoryPattern.test(url)) {
        Logger.info(`Cartier category page detected: ${url}`);
        return false;
      }
      
      // For other Cartier pages, fall back to standard detection methods
      return false;
    }
    
    // Check if it's Mango website
    if (url.includes("mango.com")) {
      // Mango product URLs have /p/ pattern in them
      // Example: https://shop.mango.com/tr/tr/p/erkek/gomlek/slim-fit/dar-kesimli-100-pamuklu-gomlek_87067899
      const mangoProductPattern = /mango\.com\/.*\/p\//;
      
      // Skip homepage and category pages
      const mangoNonProductPattern = /mango\.com\/.*\/h\//;
      
      if (mangoProductPattern.test(url)) {
        Logger.info(`Mango product URL detected: ${url}`);
        return true;
      } else if (mangoNonProductPattern.test(url)) {
        Logger.info(`Mango non-product page detected: ${url}`);
        return false;
      }
      
      // For other Mango pages, fall back to standard detection methods
      return false;
    }
    
    // Check if it's Victoria's Secret website
    if (url.includes("victoriassecret.com.tr")) {
      // Victoria's Secret product URLs contain "urun" (product) path
      // Example: https://www.victoriassecret.com.tr/urun/kadin-parfumleritester-eau-so-sexy-victoriassecret-tester-edp-100-ml-1691/
      const victoriaSecretProductPattern = /victoriassecret\.com\.tr\/.*\/urun\//;
      
      // Skip homepage and category pages
      const victoriaSecretNonProductPattern = /victoriassecret\.com\.tr\/(home|kampanya|kategori)\/?$/;
      
      if (victoriaSecretProductPattern.test(url)) {
        Logger.info(`Victoria's Secret product URL detected: ${url}`);
        return true;
      } else if (victoriaSecretNonProductPattern.test(url)) {
        Logger.info(`Victoria's Secret non-product page detected: ${url}`);
        return false;
      }
      
      // For other Victoria's Secret pages, fall back to standard detection methods
      return false;
    }
    
    // Check if it's Nocturne website
    if (url.includes("nocturne.com.tr")) {
      // Nocturne product URLs have a pattern with an underscore followed by numeric ID (_XXXXXX)
      // Also allow query parameters after the ID
      const nocturneProductPattern = /nocturne\.com\.tr\/.*_\d+($|\?)/;
      
      // Skip homepage and category pages
      const nocturneNonProductPattern = /nocturne\.com\.tr\/(ust-giyim|aksesuar|indirim|giyim|alt-giyim|dis-giyim|plaj-giyim)?$/;
      
      if (nocturneProductPattern.test(url)) {
        Logger.info(`Nocturne product URL detected: ${url}`);
        return true;
      } else if (nocturneNonProductPattern.test(url)) {
        Logger.info(`Nocturne non-product page detected: ${url}`);
        return false;
      }
      
      // For other Nocturne pages, fall back to standard detection methods
      return false;
    }
    
    const productURLPatterns = [
      /\/p\//, // Common pattern like /p/product-name
      /\/product\//, // Common pattern like /product/product-name
      /\/products\//, // Common Shopify pattern
      /-p-\d+/, // Common pattern like product-name-p-12345
      /\/pd\//, // Another common product pattern
      /\/item\//, // Common pattern for items
      /\/dp\/[A-Z0-9]{10}/, // Amazon-style product URLs
      /product_id=\d+/, // URL parameter style
      /\/prod\d+/, // product ID pattern
      /\/pr\//, // Gucci-specific pattern
      /_\d+($|\?)/, // Nocturne-specific pattern like product-name_12345 or product-name_12345?d=10322
    ];

    for (const pattern of productURLPatterns) {
      if (pattern.test(url)) {
        Logger.info(`URL matches product pattern: ${pattern}`);
        return true;
      }
    }

    return false;
  },

  // Check DOM elements common for product pages
  checkDOM: function () {
    // Elements that strongly indicate a product page
    const strongIndicators = [
      // Product forms
      'form[action*="cart"], form[action*="basket"], form[action*="bag"]',
      ".product-page, .product-detail, .product-details, .pdp, .pdp-container",
      '[itemtype="http://schema.org/Product"], [itemscope][itemtype*="Product"]',
      // Add to cart buttons
      'button[name="add"], button[id*="AddToCart"], button[class*="add-to-cart"]',
      'button[class*="addToCart"], button[class*="add_to_cart"]',
      'button[id*="add-to-cart"], button[class*="btn-cart"]',
      ".add-to-cart, .add_to_cart, .add-to-bag, .add-to-basket",
      // Product variants/options (size/color)
      'select[id*="product-select"], div[data-product-variants]',
      ".product-variants, .product-options, .product__variants",
      ".swatch, .color-swatch, .size-swatch",
      // Gucci-specific indicators
      "#product-detail-add-to-shopping-bag-form",
      ".select2-results__options",
      ".carousel-slide[data-slick-index]",
    ];

    // Check for strong indicators
    for (const selector of strongIndicators) {
      try {
        const elements = document.querySelectorAll(selector);
        if (elements && elements.length > 0) {
          Logger.info(
            `Found product indicator: ${selector} (${elements.length} elements)`
          );
          return true;
        }
      } catch (e) {
        // Skip invalid selectors
      }
    }

    // Check for combinations of weaker indicators
    let score = 0;

    // Price indicators
    const priceSelectors = [
      ".price, .product-price, .price-container, .product__price",
      'span[itemprop="price"], [data-product-price]',
      '[class*="product"][class*="price"]',
      // Gucci-specific
      ".product-detail-price",
    ];

    for (const selector of priceSelectors) {
      try {
        if (document.querySelector(selector)) {
          score += 2;
          break;
        }
      } catch (e) {
        // Skip invalid selectors
      }
    }

    // Product title/name indicators
    const titleSelectors = [
      ".product-title, .product-name, .product__title, .product__name",
      'h1[itemprop="name"], h1.product-title',
      '[class*="product"][class*="title"], [class*="product"][class*="name"]',
      // Gucci-specific
      ".pdp__info h1",
    ];

    for (const selector of titleSelectors) {
      try {
        if (document.querySelector(selector)) {
          score += 2;
          break;
        }
      } catch (e) {
        // Skip invalid selectors
      }
    }

    // Image gallery indicators
    const gallerySelectors = [
      ".product-gallery, .product-images, .product__gallery",
      '[class*="product"][class*="gallery"], [class*="product"][class*="image"]',
      ".gallery-container, .slick-slider",
      // Gucci-specific
      ".slick-track",
    ];

    for (const selector of gallerySelectors) {
      try {
        if (document.querySelector(selector)) {
          score += 1;
          break;
        }
      } catch (e) {
        // Skip invalid selectors
      }
    }

    // Description indicators
    const descSelectors = [
      ".product-description, .product__description",
      '[itemprop="description"], [class*="product"][class*="desc"]',
      // Gucci-specific
      ".product-detail-description",
    ];

    for (const selector of descSelectors) {
      try {
        if (document.querySelector(selector)) {
          score += 1;
          break;
        }
      } catch (e) {
        // Skip invalid selectors
      }
    }

    Logger.info(`DOM product indicator score: ${score}`);
    return score >= 4; // Threshold for considering it a product page
  },

  // Check meta tags for product indicators
  checkMetaTags: function () {
    // Check for Open Graph product type
    const ogType = document.querySelector('meta[property="og:type"]');
    if (ogType && ogType.content === "product") {
      Logger.info("Open Graph product type found");
      return true;
    }

    // Check for product-specific meta tags
    const productMetaTags = [
      'meta[property="product:price:amount"]',
      'meta[property="og:price:amount"]',
      'meta[property="og:availability"]',
      'meta[name="twitter:data1"][content*="$"]',
      'meta[name="twitter:label1"][content*="Price"]',
    ];

    for (const selector of productMetaTags) {
      if (document.querySelector(selector)) {
        Logger.info(`Product meta tag found: ${selector}`);
        return true;
      }
    }

    return false;
  },

  // Check for structured data markup related to products
  checkStructuredData: function () {
    const scripts = document.querySelectorAll(
      'script[type="application/ld+json"]'
    );
    for (const script of scripts) {
      try {
        const data = JSON.parse(script.textContent);

        // Function to check if the object or any nested object is a product
        const findProduct = (obj) => {
          if (!obj) return false;

          if (typeof obj === "object") {
            if (obj["@type"] === "Product") {
              return true;
            }

            if (Array.isArray(obj)) {
              for (const item of obj) {
                if (findProduct(item)) return true;
              }
            } else {
              for (const key in obj) {
                if (findProduct(obj[key])) return true;
              }
            }
          }

          return false;
        };

        if (findProduct(data)) {
          Logger.info("Product structured data found");
          return true;
        }
      } catch (e) {
        // Skip invalid JSON
      }
    }

    return false;
  },

  // Master method to check if the current page is a product page
  isProductPage: function () {
    Logger.info("Checking if page is a product page...");

    // Run all checks
    const urlCheck = this.checkURL();
    const domCheck = this.checkDOM();
    const metaCheck = this.checkMetaTags();
    const structuredDataCheck = this.checkStructuredData();

    Logger.info(
      `Product page checks - URL: ${urlCheck}, DOM: ${domCheck}, Meta: ${metaCheck}, StructuredData: ${structuredDataCheck}`
    );

    // Page is considered a product page if any of the checks succeed
    return urlCheck || domCheck || metaCheck || structuredDataCheck;
  },
};

// ==================== Data Extraction ====================

// Base extractor with common functionality
const BaseExtractor = {
  // Initialize the result object
  createResultObject: function () {
    return {
      isProductPage: true,
      url: window.location.href,
      success: false,
      extractionMethod: "generic",
      variants: {
        colors: [],
        sizes: [],
        otherOptions: [],
      },
    };
  },

  // Extract structured data (JSON-LD)
  extractStructuredData: function () {
    Logger.info("Extracting from structured data (JSON-LD)");

    try {
      const scripts = document.querySelectorAll(
        'script[type="application/ld+json"]'
      );
      if (!scripts.length) return null;

      let productData = null;

      // Search through JSON-LD scripts for product data
      for (const script of scripts) {
        try {
          if (!script.textContent) continue;

          const data = JSON.parse(script.textContent);

          // Find product in the JSON structure
          const findProduct = (obj) => {
            if (!obj) return null;

            if (obj["@type"] === "Product") {
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
            productData = product;
            Logger.debug("Found product in JSON-LD", productData);
            break;
          }
        } catch (e) {
          Logger.warn("Error parsing JSON-LD script", e);
        }
      }

      if (!productData) return null;

      // Extract the product information
      const result = this.createResultObject();
      result.extractionMethod = "structured_data";

      // Basic properties
      result.title = productData.name || null;
      result.description = productData.description || null;
      result.sku =
        productData.sku || productData.mpn || productData.productID || null;
      result.brand = productData.brand?.name || productData.brand || null;

      // Image URL
      if (productData.image) {
        if (typeof productData.image === "string") {
          result.imageUrl = FormatUtils.makeUrlAbsolute(productData.image);
        } else if (
          Array.isArray(productData.image) &&
          productData.image.length > 0
        ) {
          const imgUrl = productData.image[0].url || productData.image[0];
          result.imageUrl = FormatUtils.makeUrlAbsolute(imgUrl);
        } else if (productData.image.url) {
          result.imageUrl = FormatUtils.makeUrlAbsolute(productData.image.url);
        }
      }

      // Price and availability
      if (productData.offers) {
        let offer = productData.offers;

        if (Array.isArray(offer)) {
          offer = offer[0]; // Use first offer
        }

        if (offer) {
          result.price = FormatUtils.formatPrice(offer.price?.toString());
          result.currency =
            offer.priceCurrency ||
            FormatUtils.detectCurrency(offer.price?.toString());

          // Check for original price (sale)
          if (
            offer.highPrice &&
            offer.lowPrice &&
            offer.highPrice > offer.lowPrice
          ) {
            result.originalPrice = FormatUtils.formatPrice(
              offer.highPrice.toString()
            );
          }

          // Availability
          if (offer.availability) {
            result.availability = offer.availability;
          }
        }
      }

      // Extract color variants
      if (productData.color) {
        // Handle different formats of the color property
        if (typeof productData.color === "string") {
          result.variants.colors.push({
            text: productData.color,
            selected: true, // If it's in the main product, it's likely selected
            value: productData.color,
          });
        } else if (Array.isArray(productData.color)) {
          for (const color of productData.color) {
            if (typeof color === "string") {
              result.variants.colors.push({
                text: color,
                selected: false,
                value: color,
              });
            }
          }
        }
      }

      // Extract size variants
      if (productData.size) {
        // Handle different formats of the size property
        if (typeof productData.size === "string") {
          result.variants.sizes.push({
            text: productData.size,
            selected: true, // If it's in the main product, it's likely selected
            value: productData.size,
          });
        } else if (Array.isArray(productData.size)) {
          for (const size of productData.size) {
            if (typeof size === "string") {
              result.variants.sizes.push({
                text: size,
                selected: false,
                value: size,
              });
            }
          }
        }
      }

      // Check if we have the minimum needed information for success
      result.success = !!(result.title && result.price);

      return result;
    } catch (e) {
      Logger.error("Error extracting from structured data", e);
      return null;
    }
  },

  // Extract from meta tags
  extractMetaTags: function () {
    Logger.info("Extracting from meta tags");

    try {
      const result = this.createResultObject();
      result.extractionMethod = "meta_tags";

      // Extract title
      const titleTag = document.querySelector(
        'meta[property="og:title"], meta[name="twitter:title"]'
      );
      if (titleTag) {
        result.title = titleTag.getAttribute("content");
      }

      // Extract description
      const descTag = document.querySelector(
        'meta[property="og:description"], meta[name="twitter:description"], meta[name="description"]'
      );
      if (descTag) {
        result.description = descTag.getAttribute("content");
      }

      // Extract image
      const imageTag = document.querySelector(
        'meta[property="og:image"], meta[property="og:image:secure_url"], meta[name="twitter:image"]'
      );
      if (imageTag) {
        result.imageUrl = FormatUtils.makeUrlAbsolute(
          imageTag.getAttribute("content")
        );
      }

      // Extract price
      const priceTag = document.querySelector(
        'meta[property="product:price:amount"], meta[property="og:price:amount"], meta[name="twitter:data1"][content*="$"]'
      );
      if (priceTag) {
        result.price = FormatUtils.formatPrice(
          priceTag.getAttribute("content")
        );

        // Get currency if available
        const currencyTag = document.querySelector(
          'meta[property="product:price:currency"], meta[property="og:price:currency"]'
        );
        result.currency = currencyTag
          ? currencyTag.getAttribute("content")
          : FormatUtils.detectCurrency(priceTag.getAttribute("content"));
      }

      // Extract brand
      const brandTag = document.querySelector(
        'meta[property="product:brand"], meta[property="og:brand"]'
      );
      if (brandTag) {
        result.brand = brandTag.getAttribute("content");
      }

      // Extract availability
      const availabilityTag = document.querySelector(
        'meta[property="product:availability"], meta[property="og:availability"]'
      );
      if (availabilityTag) {
        result.availability = availabilityTag.getAttribute("content");
      }

      // Check if we have the minimum needed information for success
      result.success = !!(result.title && result.price);

      if (result.success) {
        return result;
      }

      return null;
    } catch (e) {
      Logger.error("Error extracting from meta tags", e);
      return null;
    }
  },

  // Generic DOM-based extraction
  extractFromDOM: function () {
    Logger.info("Extracting from DOM elements (generic)");

    try {
      const result = this.createResultObject();

      // Extract product title
      const titleSelectors = [
        "h1.product-title, h1.product-name, h1.product__title, h1.product__name",
        'h1[itemprop="name"]',
        ".product-title, .product-name, .product__title, .product__name",
        ".product-detail__title, .product-detail__name",
        ".pdp-title, .pdp-name",
      ];

      const titleElement = DOMUtils.querySelector(titleSelectors);
      if (titleElement) {
        result.title = DOMUtils.getTextContent(titleElement);
        Logger.debug(`Found title: ${result.title}`);
      } else {
        // Fallback: use the page title
        const pageTitle = document.title;
        if (pageTitle) {
          // Often page titles follow pattern: "Product Name | Brand Name"
          const titleParts = pageTitle.split("|");
          if (titleParts.length > 1) {
            result.title = titleParts[0].trim();
          } else {
            result.title = pageTitle;
          }
          Logger.debug(`Using page title: ${result.title}`);
        }
      }

      // Extract product price
      const priceSelectors = [
        ".product-price, .product__price, .price-item--regular",
        ".price-current, .current-price, .now-price",
        '[itemprop="price"], [data-product-price]',
        ".price:not(.price--old):not(.price--original)",
        ".product-detail-price, .product-info__price",
      ];

      const priceElement = DOMUtils.querySelector(priceSelectors);
      if (priceElement) {
        const priceText = DOMUtils.getTextContent(priceElement);
        result.price = FormatUtils.formatPrice(priceText);
        result.currency = FormatUtils.detectCurrency(priceText);
        Logger.debug(`Found price: ${result.price} ${result.currency}`);
      } else {
        // Try to find any text that looks like a price
        const regex = /([0-9.,]+)\s*(?:€|\$|£|TL|₺)/;
        const allTextElements = document.querySelectorAll("p, span, div");

        for (const element of allTextElements) {
          const text = DOMUtils.getTextContent(element);
          const match = text.match(regex);

          if (match) {
            result.price = FormatUtils.formatPrice(match[0]);
            result.currency = FormatUtils.detectCurrency(match[0]);
            Logger.debug(
              `Found price by regex: ${result.price} ${result.currency}`
            );
            break;
          }
        }
      }

      // Extract original price (for sales)
      const originalPriceSelectors = [
        ".original-price, .regular-price, .old-price",
        ".price--old, .price--original, .price-item--regular.price--on-sale",
        ".was-price, .compare-at-price",
        "[data-original-price], [data-compare-price]",
      ];

      const originalPriceElement = DOMUtils.querySelector(
        originalPriceSelectors
      );
      if (originalPriceElement) {
        const originalPriceText = DOMUtils.getTextContent(originalPriceElement);
        result.originalPrice = FormatUtils.formatPrice(originalPriceText);
        Logger.debug(`Found original price: ${result.originalPrice}`);
      }

      // Extract product image
      const bestImage = DOMUtils.findLargestImage();
      if (bestImage) {
        result.imageUrl = FormatUtils.makeUrlAbsolute(
          bestImage.src || bestImage.getAttribute("data-src")
        );
        Logger.debug(`Found image: ${result.imageUrl}`);
      }

      // Extract product description
      const descriptionSelectors = [
        ".product-description, .product__description",
        '[itemprop="description"]',
        ".description, .desc, .product-desc",
        ".product-detail-description, .product-details__description",
      ];

      const descriptionElement = DOMUtils.querySelector(descriptionSelectors);
      if (descriptionElement) {
        result.description = FormatUtils.cleanText(
          DOMUtils.getTextContent(descriptionElement)
        );
        Logger.debug("Found product description");
      }

      // Extract product brand
      const brandSelectors = [
        ".product-brand, .product__brand",
        '[itemprop="brand"]',
        ".brand, .brand-name",
      ];

      const brandElement = DOMUtils.querySelector(brandSelectors);
      if (brandElement) {
        result.brand = DOMUtils.getTextContent(brandElement);
        Logger.debug(`Found brand: ${result.brand}`);
      }

      // Extract SKU
      const skuSelectors = [
        ".product-sku, .product__sku",
        '[itemprop="sku"]',
        ".sku, .sku-number",
        "[data-product-sku]",
      ];

      const skuElement = DOMUtils.querySelector(skuSelectors);
      if (skuElement) {
        result.sku = DOMUtils.getTextContent(skuElement);
        Logger.debug(`Found SKU: ${result.sku}`);
      }

      // Extract availability
      const availabilitySelectors = [
        ".product-availability, .product__availability",
        '[itemprop="availability"]',
        ".availability, .stock-status",
        "[data-product-available]",
      ];

      const availabilityElement = DOMUtils.querySelector(availabilitySelectors);
      if (availabilityElement) {
        result.availability = DOMUtils.getTextContent(availabilityElement);
        Logger.debug(`Found availability: ${result.availability}`);
      }

      // Extract color variants
      this.extractColorVariants(result);

      // Extract size variants
      this.extractSizeVariants(result);

      // Check if we have the minimum needed information for success
      result.success = !!(result.title && result.price);

      return result;
    } catch (e) {
      Logger.error("Error extracting from DOM", e);
      return null;
    }
  },

  // Helper method to extract color variants
  extractColorVariants: function (result) {
    try {
      const colorSelectors = [
        // Color swatches
        ".color-swatch, .color-selector, .color-option",
        // Color dropdowns/selects
        'select[data-option="color"] option, select[name*="color"] option',
        // Color labels/buttons
        ".color-label, .color-name, .color-title",
        '[data-option-name="color"] [data-value], [data-option="Color"] [data-value]',
      ];

      // Try each selector group
      for (const selectorGroup of colorSelectors) {
        const colorElements = document.querySelectorAll(selectorGroup);
        if (colorElements && colorElements.length > 0) {
          Logger.debug(
            `Found ${colorElements.length} color options with selector: ${selectorGroup}`
          );

          for (const element of colorElements) {
            // Get color name/text
            let colorText =
              DOMUtils.getAttribute(element, "title") ||
              DOMUtils.getAttribute(element, "data-color-name") ||
              DOMUtils.getAttribute(element, "data-value") ||
              DOMUtils.getAttribute(element, "value") ||
              DOMUtils.getTextContent(element);

            if (!colorText || colorText.toLowerCase() === "select color")
              continue;

            // Determine if this color is selected
            const isSelected =
              element.selected ||
              element.hasAttribute("aria-selected") ||
              element.classList.contains("selected") ||
              element.classList.contains("active") ||
              element.classList.contains("current");

            // Try to get color value (could be color code or image)
            let colorValue =
              DOMUtils.getAttribute(element, "data-color") ||
              DOMUtils.getAttribute(element, "data-color-value") ||
              DOMUtils.getAttribute(element, "data-value");

            // If no explicit value, try background color or image
            if (!colorValue) {
              const img = element.querySelector("img");
              if (img && img.src) {
                colorValue = FormatUtils.makeUrlAbsolute(img.src);
              } else {
                try {
                  const style = window.getComputedStyle(element);
                  if (
                    style.backgroundColor &&
                    style.backgroundColor !== "rgba(0, 0, 0, 0)"
                  ) {
                    colorValue = style.backgroundColor;
                  }
                } catch (e) {
                  // Ignore style errors
                }
              }
            }

            // Add color to variants if not already present
            if (!result.variants.colors.some((c) => c.text === colorText)) {
              result.variants.colors.push({
                text: colorText,
                selected: isSelected,
                value: colorValue || colorText,
              });

              Logger.debug(
                `Added color: ${colorText}, selected: ${isSelected}`
              );
            }
          }

          // If we found colors, stop searching
          if (result.variants.colors.length > 0) break;
        }
      }

      // Special case: look for color in tooltips (often used in carousels)
      if (result.variants.colors.length === 0) {
        const tooltipElements = document.querySelectorAll(
          "[data-tooltip], [title], [aria-label]"
        );
        for (const element of tooltipElements) {
          const tooltipText =
            DOMUtils.getAttribute(element, "data-tooltip") ||
            DOMUtils.getAttribute(element, "title") ||
            DOMUtils.getAttribute(element, "aria-label");

          if (tooltipText && tooltipText.length < 30) {
            const img = element.querySelector("img");
            const isImage = img || element.tagName === "IMG";

            if (isImage) {
              result.variants.colors.push({
                text: tooltipText,
                selected:
                  element.classList.contains("selected") ||
                  element.classList.contains("active"),
                value: img ? FormatUtils.makeUrlAbsolute(img.src) : tooltipText,
              });

              Logger.debug(`Added color from tooltip: ${tooltipText}`);
            }
          }
        }
      }
    } catch (e) {
      Logger.warn("Error extracting color variants", e);
    }
  },

  // Helper method to extract size variants
  extractSizeVariants: function (result) {
    try {
      const sizeSelectors = [
        // Size swatches/options
        ".size-swatch, .size-selector, .size-option",
        ".size-selector li, .size-list li, .size-options li",
        // Size dropdowns/selects
        'select[data-option="size"] option, select[name*="size"] option',
        // Size labels/buttons
        ".size-label, .size-name, .size-title",
        '[data-option-name="size"] [data-value], [data-option="Size"] [data-value]',
      ];

      // Try each selector group
      for (const selectorGroup of sizeSelectors) {
        const sizeElements = document.querySelectorAll(selectorGroup);
        if (sizeElements && sizeElements.length > 0) {
          Logger.debug(
            `Found ${sizeElements.length} size options with selector: ${selectorGroup}`
          );

          for (const element of sizeElements) {
            // Get size text
            let sizeText =
              DOMUtils.getAttribute(element, "title") ||
              DOMUtils.getAttribute(element, "data-size-name") ||
              DOMUtils.getAttribute(element, "data-value") ||
              DOMUtils.getAttribute(element, "value") ||
              DOMUtils.getTextContent(element);

            if (!sizeText || sizeText.toLowerCase() === "select size") continue;

            // Determine if this size is selected
            const isSelected =
              element.selected ||
              element.hasAttribute("aria-selected") ||
              element.classList.contains("selected") ||
              element.classList.contains("active") ||
              element.classList.contains("current");

            // Add size to variants if not already present
            if (!result.variants.sizes.some((s) => s.text === sizeText)) {
              result.variants.sizes.push({
                text: sizeText,
                selected: isSelected,
                value: sizeText,
              });

              Logger.debug(`Added size: ${sizeText}, selected: ${isSelected}`);
            }
          }

          // If we found sizes, stop searching
          if (result.variants.sizes.length > 0) break;
        }
      }
    } catch (e) {
      Logger.warn("Error extracting size variants", e);
    }
  },
};

// Shopify-specific extractor
const ShopifyExtractor = {
  // Check if the current page is a Shopify store
  isShopify: function () {
    // Check for Shopify-specific meta tag
    const shopifyTag = document.querySelector(
      'meta[name="shopify-digital-wallet"]'
    );
    if (shopifyTag) return true;

    // Check for Shopify-specific scripts
    const shopifyScripts = document.querySelector(
      'script[src*="shopify"], script[src*="cdn.shop"]'
    );
    if (shopifyScripts) return true;

    // Check for Shopify object in window
    if (window.Shopify) return true;

    return false;
  },

  // Extract product info from Shopify store
  extract: function () {
    Logger.info("Extracting product info from Shopify store");

    try {
      const result = BaseExtractor.createResultObject();
      result.extractionMethod = "shopify";

      // Shopify stores typically expose product JSON
      let productJson = null;

      // Try to find product JSON from meta tag
      const productMetaTag = document.querySelector(
        'meta[property="product:retailer_item_id"]'
      );
      if (productMetaTag) {
        const productId = productMetaTag.getAttribute("content");
        const scriptTag = document.querySelector(
          `script[id="ProductJson-${productId}"], script[data-product-json]`
        );
        if (scriptTag) {
          try {
            productJson = JSON.parse(scriptTag.textContent);
          } catch (e) {
            Logger.warn("Failed to parse product JSON from script tag", e);
          }
        }
      }

      // Try to find product JSON from window object
      if (
        !productJson &&
        window.ShopifyAnalytics &&
        window.ShopifyAnalytics.meta
      ) {
        productJson = window.ShopifyAnalytics.meta.product;
      }

      // Try to find product JSON from variable
      if (!productJson) {
        const scripts = document.querySelectorAll("script:not([src])");
        for (const script of scripts) {
          const content = script.textContent;
          if (
            content.includes("var product =") ||
            content.includes("window.product =")
          ) {
            try {
              // Extract the JSON object using regex
              const match =
                content.match(/var\s+product\s*=\s*({.+?});/s) ||
                content.match(/window\.product\s*=\s*({.+?});/s);
              if (match && match[1]) {
                productJson = JSON.parse(match[1]);
              }
            } catch (e) {
              // Skip invalid JSON
            }
          }
        }
      }

      // Extract from product JSON if found
      if (productJson) {
        Logger.debug("Found Shopify product JSON", productJson);

        result.title = productJson.title;
        result.description = productJson.description;
        result.sku = productJson.sku || productJson.id;
        result.brand = productJson.vendor;

        // Extract image
        if (
          productJson.featured_image ||
          (productJson.images && productJson.images.length > 0)
        ) {
          const imageUrl = productJson.featured_image || productJson.images[0];
          result.imageUrl = FormatUtils.makeUrlAbsolute(imageUrl);
        }

        // Extract variants
        if (productJson.variants && productJson.variants.length > 0) {
          const variant = productJson.variants[0]; // Use first variant for price
          result.price = variant.price / 100; // Shopify prices are in cents

          // Find currency
          if (variant.currency) {
            result.currency = variant.currency;
          } else {
            // Try to find currency from meta tag
            const currencyMeta = document.querySelector(
              'meta[property="og:price:currency"]'
            );
            result.currency = currencyMeta
              ? currencyMeta.getAttribute("content")
              : "USD";
          }

          // Extract compare_at_price if available
          if (
            variant.compare_at_price &&
            variant.compare_at_price > variant.price
          ) {
            result.originalPrice = variant.compare_at_price / 100;
          }
        }

        // Extract options (colors, sizes, etc.)
        if (productJson.options) {
          for (const option of productJson.options) {
            const optionName = option.name.toLowerCase();
            const values = option.values;

            if (optionName.includes("color") || optionName.includes("colour")) {
              for (const value of values) {
                result.variants.colors.push({
                  text: value,
                  selected: false, // Can't determine from JSON
                  value: value,
                });
              }
            } else if (optionName.includes("size")) {
              for (const value of values) {
                result.variants.sizes.push({
                  text: value,
                  selected: false, // Can't determine from JSON
                  value: value,
                });
              }
            } else {
              for (const value of values) {
                result.variants.otherOptions.push({
                  text: value,
                  selected: false,
                  value: value,
                });
              }
            }
          }
        }

        // If we have product JSON, mark as success
        result.success = true;
        return result;
      }

      // Fallback to DOM extraction if no product JSON found
      Logger.info(
        "No Shopify product JSON found, falling back to DOM extraction"
      );

      // Attempt to extract from DOM
      return BaseExtractor.extractFromDOM();
    } catch (e) {
      Logger.error("Error extracting from Shopify store", e);
      return null;
    }
  },
};

// WooCommerce-specific extractor
const WooCommerceExtractor = {
  // Check if the current page is a WooCommerce store
  isWooCommerce: function () {
    // Check for WooCommerce-specific classes
    const wooElements = document.querySelector(
      ".woocommerce, .woocommerce-page"
    );
    if (wooElements) return true;

    // Check for WooCommerce-specific scripts
    const wooScripts = document.querySelector('script[src*="woocommerce"]');
    if (wooScripts) return true;

    // Check for WooCommerce object in window
    if (window.wc_add_to_cart_params || window.woocommerce_params) return true;

    return false;
  },

  // Extract product info from WooCommerce store
  extract: function () {
    Logger.info("Extracting product info from WooCommerce store");

    try {
      const result = BaseExtractor.createResultObject();
      result.extractionMethod = "woocommerce";

      // Extract product title
      const titleElement = document.querySelector(".product_title");
      if (titleElement) {
        result.title = DOMUtils.getTextContent(titleElement);
      }

      // Extract product price
      const priceElement = document.querySelector(
        ".price .woocommerce-Price-amount"
      );
      if (priceElement) {
        const priceText = DOMUtils.getTextContent(priceElement);
        result.price = FormatUtils.formatPrice(priceText);
        result.currency = FormatUtils.detectCurrency(priceText);
      }

      // Extract sale price if available
      const originalPriceElement = document.querySelector(
        ".price del .woocommerce-Price-amount"
      );
      if (originalPriceElement) {
        const originalPriceText = DOMUtils.getTextContent(originalPriceElement);
        result.originalPrice = FormatUtils.formatPrice(originalPriceText);
      }

      // Extract product image
      const imageElement = document.querySelector(
        ".woocommerce-product-gallery__image img"
      );
      if (imageElement) {
        result.imageUrl = FormatUtils.makeUrlAbsolute(
          imageElement.src || imageElement.getAttribute("data-src")
        );
      }

      // Extract product description
      const descriptionElement = document.querySelector(
        ".woocommerce-product-details__short-description"
      );
      if (descriptionElement) {
        result.description = DOMUtils.getTextContent(descriptionElement);
      }

      // Extract product SKU
      const skuElement = document.querySelector(".sku");
      if (skuElement) {
        result.sku = DOMUtils.getTextContent(skuElement);
      }

      // Extract product availability
      const availabilityElement = document.querySelector(".stock");
      if (availabilityElement) {
        result.availability = DOMUtils.getTextContent(availabilityElement);
      }

      // Extract color variations
      const colorElements = document.querySelectorAll(
        'select[name^="attribute_pa_color"] option, .color-variable-item'
      );
      for (const element of colorElements) {
        const colorText = DOMUtils.getTextContent(element);
        if (colorText && colorText.toLowerCase() !== "choose an option") {
          result.variants.colors.push({
            text: colorText,
            selected:
              element.selected || element.classList.contains("selected"),
            value: colorText,
          });
        }
      }

      // Extract size variations
      const sizeElements = document.querySelectorAll(
        'select[name^="attribute_pa_size"] option, .size-variable-item'
      );
      for (const element of sizeElements) {
        const sizeText = DOMUtils.getTextContent(element);
        if (sizeText && sizeText.toLowerCase() !== "choose an option") {
          result.variants.sizes.push({
            text: sizeText,
            selected:
              element.selected || element.classList.contains("selected"),
            value: sizeText,
          });
        }
      }

      // Check if we have the minimum needed information for success
      result.success = !!(result.title && result.price);

      return result;
    } catch (e) {
      Logger.error("Error extracting from WooCommerce store", e);
      return null;
    }
  },
};

// Gucci-specific extractor
const GucciExtractor = {
  // Check if the current page is Gucci
  isGucci: function () {
    return window.location.hostname.includes("gucci.com");
  },

  // Extract product info from Gucci site
  extract: function () {
    Logger.info("Extracting product info from Gucci store");

    try {
      const result = BaseExtractor.createResultObject();
      result.extractionMethod = "gucci";
      result.brand = "Gucci"; // Set brand directly

      // Extract product title
      const titleSelectors = [
        'h1[itemprop="name"]',
        "h1.product__name",
        ".product-info h1",
        ".pdp__info h1",
      ];

      const titleElement = DOMUtils.querySelector(titleSelectors);
      if (titleElement) {
        result.title = DOMUtils.getTextContent(titleElement);
        Logger.debug(`Found Gucci title: ${result.title}`);
      } else {
        // Fallback to page title
        const pageTitle = document.title;
        if (pageTitle) {
          // Often follows pattern: "Product Name | Gucci® TR"
          const titleParts = pageTitle.split("|");
          if (titleParts.length > 1) {
            result.title = titleParts[0].trim();
          } else {
            result.title = pageTitle;
          }
          Logger.debug(`Using page title: ${result.title}`);
        }
      }

      // Extract product price
      const priceSelectors = [
        '[itemprop="price"]',
        ".product-detail-price",
        ".price-value",
        ".product__price",
        ".pdp__info .price",
      ];

      const priceElement = DOMUtils.querySelector(priceSelectors);
      if (priceElement) {
        const priceText = DOMUtils.getTextContent(priceElement);
        result.price = FormatUtils.formatPrice(priceText);
        result.currency = FormatUtils.detectCurrency(priceText);
        Logger.debug(`Found Gucci price: ${result.price} ${result.currency}`);
      }

      // Extract original price (for sales)
      const originalPriceSelectors = [
        ".product-detail-original-price",
        ".original-price",
        ".price-original",
      ];

      const originalPriceElement = DOMUtils.querySelector(
        originalPriceSelectors
      );
      if (originalPriceElement) {
        const originalPriceText = DOMUtils.getTextContent(originalPriceElement);
        result.originalPrice = FormatUtils.formatPrice(originalPriceText);
        Logger.debug(`Found Gucci original price: ${result.originalPrice}`);
      }

      // Extract product description
      const descriptionSelectors = [
        ".product-detail-description",
        ".product-description",
        ".description",
        '[itemprop="description"]',
      ];

      const descriptionElement = DOMUtils.querySelector(descriptionSelectors);
      if (descriptionElement) {
        result.description = DOMUtils.getTextContent(descriptionElement);
        Logger.debug("Found Gucci description");
      }

      // Extract product SKU
      const skuSelectors = [".product-detail-sku", ".sku", '[itemprop="sku"]'];

      const skuElement = DOMUtils.querySelector(skuSelectors);
      if (skuElement) {
        result.sku = DOMUtils.getTextContent(skuElement);
        Logger.debug(`Found Gucci SKU: ${result.sku}`);
      } else {
        // Extract SKU from URL
        const skuMatch = window.location.pathname.match(/\/(\w+)$/);
        if (skuMatch) {
          result.sku = skuMatch[1];
          Logger.debug(`Extracted Gucci SKU from URL: ${result.sku}`);
        }
      }

      // Find best image first - used for main product image
      // Get the image from the currently selected color/variant
      const currentSlide = document.querySelector(
        ".carousel-slide.slick-current, .carousel-slide.slick-active"
      );
      if (currentSlide) {
        const img = currentSlide.querySelector("img");
        if (img) {
          // Try to get the high-res version first by getting the real source or srcset
          const sources = currentSlide.querySelectorAll("source");
          let bestSource = null;
          let bestWidth = 0;

          for (const source of sources) {
            // Check if it's a high-res image source
            const srcset = source.getAttribute("srcset");
            if (srcset) {
              const mediaQuery = source.getAttribute("media");
              if (mediaQuery && mediaQuery.includes("retina")) {
                // This is a retina/high-res image, prefer it
                result.imageUrl = FormatUtils.makeUrlAbsolute(srcset);
                Logger.debug(`Found Gucci retina image: ${result.imageUrl}`);
                break;
              }

              // Check if this source has a width attribute or data-image-size
              const sizeAttr = source.getAttribute("data-image-size");
              let width = 0;

              if (sizeAttr) {
                // Try to extract the width from something like "standard-retina" or "730x490"
                const sizeMatch = sizeAttr.match(/(\d+)x\d+/);
                if (sizeMatch) {
                  width = parseInt(sizeMatch[1], 10);
                } else if (sizeAttr.includes("standard")) {
                  width = 500; // Assume standard is decent size
                } else if (sizeAttr.includes("large")) {
                  width = 800; // Assume large is bigger
                }
              }

              if (width > bestWidth) {
                bestWidth = width;
                bestSource = srcset;
              }
            }
          }

          // Use the best source found, or fallback to img src
          if (bestSource) {
            result.imageUrl = FormatUtils.makeUrlAbsolute(bestSource);
            Logger.debug(`Found Gucci best source image: ${result.imageUrl}`);
          } else {
            result.imageUrl = FormatUtils.makeUrlAbsolute(
              img.src || img.getAttribute("data-src")
            );
            Logger.debug(`Found Gucci image: ${result.imageUrl}`);
          }
        }
      } else {
        // Fallback to any large image on the page
        const bestImage = DOMUtils.findLargestImage();
        if (bestImage) {
          result.imageUrl = FormatUtils.makeUrlAbsolute(
            bestImage.src || bestImage.getAttribute("data-src")
          );
          Logger.debug(`Found Gucci fallback image: ${result.imageUrl}`);
        }
      }

      // Extract sizes - specifically for Gucci's Select2 implementation
      this.extractGucciSizes(result);

      // Extract colors - specifically for Gucci's carousel implementation
      this.extractGucciColors(result);

      // Check if we have the minimum needed information for success
      result.success = !!(result.title && result.price);

      return result;
    } catch (e) {
      Logger.error("Error extracting from Gucci site", e);
      return null;
    }
  },

  // Helper method to extract Gucci sizes - completely rewritten to handle their specific Select2 structure
  extractGucciSizes: function (result) {
    try {
      Logger.info("Extracting Gucci sizes");

      // Try direct approach with Select2 dropdown - this is the active dropdown
      const select2Results = document.querySelector(
        ".select2-results__options"
      );

      if (select2Results) {
        const sizeOptions = select2Results.querySelectorAll(
          ".select2-results__option"
        );
        Logger.debug(
          `Found ${sizeOptions.length} Gucci size options in Select2 dropdown`
        );

        for (const option of sizeOptions) {
          // Skip the placeholder "Select size" option
          if (option.id.endsWith("-1")) continue;

          // Get the size text from the content span
          const sizeContentSpan = option.querySelector(
            ".custom-select-content-size"
          );
          if (!sizeContentSpan) continue;

          const sizeText = DOMUtils.getTextContent(sizeContentSpan);
          if (!sizeText) continue;

          // Check if this option is selected
          const isSelected = option.getAttribute("aria-selected") === "true";

          result.variants.sizes.push({
            text: sizeText,
            selected: isSelected,
            value: sizeText,
          });

          Logger.debug(
            `Added Gucci size from Select2: ${sizeText}, selected: ${isSelected}`
          );
        }

        if (result.variants.sizes.length > 0) {
          return; // Successfully found sizes in Select2 dropdown
        }
      }

      // If Select2 dropdown not found, try to find the sizes in the page content
      // This could be a hidden select element that Select2 is attached to
      const sizeSelectOptions = document.querySelectorAll(
        ".size-dropdown select option, #pdp-size-selector option"
      );

      if (sizeSelectOptions && sizeSelectOptions.length > 0) {
        Logger.debug(
          `Found ${sizeSelectOptions.length} Gucci size options using selector: .size-dropdown select option`
        );

        for (const option of sizeSelectOptions) {
          // Skip placeholder option
          if (option.value === "-1" || option.disabled) continue;

          const sizeText = DOMUtils.getTextContent(option);
          if (!sizeText) continue;

          const isSelected = option.selected;

          result.variants.sizes.push({
            text: sizeText,
            selected: isSelected,
            value: sizeText,
          });

          Logger.debug(
            `Added Gucci size: ${sizeText}, selected: ${isSelected}`
          );
        }

        return; // Successfully found sizes in select element
      }

      // If still no sizes found, try to find any elements with specific Gucci classes
      const sizeElements = document.querySelectorAll(
        ".custom-select-content-size"
      );

      if (sizeElements && sizeElements.length > 0) {
        Logger.debug(
          `Found ${sizeElements.length} Gucci size elements using .custom-select-content-size`
        );

        for (const element of sizeElements) {
          const sizeText = DOMUtils.getTextContent(element);
          if (!sizeText) continue;

          // Can't determine selected state in this case

          result.variants.sizes.push({
            text: sizeText,
            selected: false,
            value: sizeText,
          });

          Logger.debug(`Added Gucci size: ${sizeText}, selected: false`);
        }
      }
    } catch (e) {
      Logger.warn("Error extracting Gucci sizes", e);
    }
  },

  // Helper method to extract Gucci colors - completely rewritten to handle their carousel structure
  extractGucciColors: function (result) {
    try {
      Logger.info("Extracting Gucci colors");

      // Find all carousel slides from the Slick carousel
      const colorSlides = document.querySelectorAll(".carousel-slide");

      if (colorSlides && colorSlides.length > 0) {
        Logger.debug(
          `Found ${colorSlides.length} potential color slides in carousel`
        );

        const uniqueColors = new Set(); // To prevent duplicates

        for (const slide of colorSlides) {
          // Get the color name from tooltip data attribute
          const tooltipContent = slide.querySelector(
            "[data-gg-tooltip--content]"
          );
          if (!tooltipContent) continue;

          const colorText = DOMUtils.getTextContent(tooltipContent);
          if (!colorText || uniqueColors.has(colorText)) continue;

          uniqueColors.add(colorText); // Add to set to prevent duplicates

          // Check if this is the selected/current color slide
          const isSelected =
            slide.classList.contains("slick-current") ||
            (slide.classList.contains("slick-active") &&
              slide.getAttribute("data-slick-index") === "0");

          // Get the image for this color (important for color variants)
          const img = slide.querySelector("img");
          let imageUrl = null;

          if (img) {
            // First try to get high-res image from source elements
            const sources = slide.querySelectorAll("source");
            let bestSource = null;
            let bestWidth = 0;

            for (const source of sources) {
              // Check if it's a high-res image source
              const srcset = source.getAttribute("srcset");
              if (srcset) {
                const mediaQuery = source.getAttribute("media");
                if (mediaQuery && mediaQuery.includes("retina")) {
                  // This is a retina/high-res image, prefer it
                  bestSource = srcset;
                  break;
                }

                // Check if this source has a width attribute or data-image-size
                const sizeAttr = source.getAttribute("data-image-size");
                let width = 0;

                if (sizeAttr) {
                  // Try to extract the width from something like "standard-retina" or "730x490"
                  const sizeMatch = sizeAttr.match(/(\d+)x\d+/);
                  if (sizeMatch) {
                    width = parseInt(sizeMatch[1], 10);
                  } else if (sizeAttr.includes("standard")) {
                    width = 500; // Assume standard is decent size
                  } else if (sizeAttr.includes("large")) {
                    width = 800; // Assume large is bigger
                  }
                }

                if (width > bestWidth) {
                  bestWidth = width;
                  bestSource = srcset;
                }
              }
            }

            // Use the best source found, or fallback to img src
            if (bestSource) {
              imageUrl = FormatUtils.makeUrlAbsolute(bestSource);
            } else {
              imageUrl = FormatUtils.makeUrlAbsolute(
                img.src || img.getAttribute("data-src")
              );
            }
          }

          // Add color to variants
          result.variants.colors.push({
            text: colorText,
            selected: isSelected,
            value: imageUrl || colorText, // Also store the image URL separately
          });

          Logger.debug(
            `Added Gucci color from carousel: ${colorText}, selected: ${isSelected}`
          );
        }

        return; // Successfully found colors in carousel
      }

      // If carousel not found, try other possible sources of color info
      const colorElements = document.querySelectorAll(
        "[data-gg-tooltip--content]"
      );

      if (colorElements && colorElements.length > 0) {
        Logger.debug(
          `Found ${colorElements.length} tooltip elements with color info`
        );

        const uniqueColors = new Set(); // To prevent duplicates

        for (const element of colorElements) {
          const colorText = DOMUtils.getTextContent(element);
          if (!colorText || uniqueColors.has(colorText)) continue;

          uniqueColors.add(colorText); // Add to set to prevent duplicates

          // Can't determine selected state in this case

          result.variants.colors.push({
            text: colorText,
            selected: false,
            value: colorText,
          });

          Logger.debug(`Added Gucci color from tooltip: ${colorText}`);
        }
      }
    } catch (e) {
      Logger.warn("Error extracting Gucci colors", e);
    }
  },
};

const ZaraExtractor = {
  // Check if the current page is Zara
  isZara: function () {
    return window.location.hostname.includes("zara.com");
  },

  // Extract product info from Zara site
  extract: function () {
    Logger.info("Extracting product info from Zara store");

    try {
      const result = BaseExtractor.createResultObject();
      result.extractionMethod = "zara";
      result.brand = "Zara"; // Set brand directly

      // Extract product title
      const titleSelectors = [
        ".product-detail-info h1",
        ".product-detail-info__header h1",
        '[data-qa-qualifier="product-name"]',
        ".product-detail-card-info__title h1",
      ];

      const titleElement = DOMUtils.querySelector(titleSelectors);
      if (titleElement) {
        result.title = DOMUtils.getTextContent(titleElement);
        Logger.debug(`Found Zara title: ${result.title}`);
      }

      // Extract product price
      const priceSelectors = [
        ".price__amount",
        '[data-qa-qualifier="product-price"]',
        ".product-detail-info__price span",
        ".product-detail-card-info__prices .money-amount__main",
      ];

      const priceElement = DOMUtils.querySelector(priceSelectors);
      if (priceElement) {
        const priceText = DOMUtils.getTextContent(priceElement);
        result.price = FormatUtils.formatPrice(priceText);
        result.currency = FormatUtils.detectCurrency(priceText);
        Logger.debug(`Found Zara price: ${result.price} ${result.currency}`);
      }

      // Extract original price (for sales)
      const originalPriceSelectors = [
        ".price__amount--old",
        ".product-detail-info__price .line-through",
        ".product-detail-card-info__prices .money-amount__main--crossed-out",
      ];

      const originalPriceElement = DOMUtils.querySelector(
        originalPriceSelectors
      );
      if (originalPriceElement) {
        const originalPriceText = DOMUtils.getTextContent(originalPriceElement);
        result.originalPrice = FormatUtils.formatPrice(originalPriceText);
        Logger.debug(`Found Zara original price: ${result.originalPrice}`);
      }

      // Extract product description
      const descriptionSelectors = [
        ".product-detail-description",
        ".product-detail-info__description",
        '[data-qa-qualifier="product-description"]',
      ];

      const descriptionElement = DOMUtils.querySelector(descriptionSelectors);
      if (descriptionElement) {
        result.description = DOMUtils.getTextContent(descriptionElement);
        Logger.debug("Found Zara description");
      }

      // Extract product SKU/reference
      const skuSelectors = [
        ".product-detail-info__reference",
        '[data-qa-qualifier="product-reference"]',
        ".product-reference span",
      ];

      const skuElement = DOMUtils.querySelector(skuSelectors);
      if (skuElement) {
        result.sku = DOMUtils.getTextContent(skuElement).replace(/\D/g, "");
        Logger.debug(`Found Zara SKU: ${result.sku}`);
      }

      // Extract product image
      this.extractZaraProductImage(result);

      // Extract Zara-specific color variants - completely customized for their HTML structure
      const colorOptions = this.extractZaraColors();

      // Extract Zara-specific size variants - handles their unique approach to size display
      const sizeOptions = this.extractZaraSizes();

      // CRITICAL FIX: Properly assign ALL colors and sizes to the result object
      if (colorOptions && colorOptions.length > 0) {
        result.variants.colors = colorOptions;
        Logger.debug(`Added ${colorOptions.length} colors to result`);
      }

      if (sizeOptions && sizeOptions.length > 0) {
        result.variants.sizes = sizeOptions;
        Logger.debug(`Added ${sizeOptions.length} sizes to result`);
      }

      // Check if we have the minimum needed information for success
      result.success = !!(result.title && result.price);

      return result;
    } catch (e) {
      Logger.error("Error extracting from Zara site", e);
      return null;
    }
  },

  // Helper method to extract Zara product image
  extractZaraProductImage: function (result) {
    try {
      // First try to get the main product image
      const mainImageSelectors = [
        ".product-detail-images img",
        ".media-image img",
        ".product-detail-card-images img",
      ];

      let imageElement = null;

      // Try each selector
      for (const selector of mainImageSelectors) {
        const images = document.querySelectorAll(selector);
        if (images && images.length > 0) {
          // Try to find the largest or most visible image
          for (const img of images) {
            if (DOMUtils.isVisible(img) && img.naturalWidth > 200) {
              imageElement = img;
              break;
            }
          }

          // If we didn't find a good visible image, just use the first one
          if (!imageElement && images.length > 0) {
            imageElement = images[0];
          }

          if (imageElement) break;
        }
      }

      // If we found an image, extract its URL
      if (imageElement) {
        // Try to get high resolution version first
        const srcset = imageElement.getAttribute("srcset");
        if (srcset) {
          // Parse srcset to get the highest resolution image
          const srcsetParts = srcset.split(",");
          let largestImage = "";
          let largestWidth = 0;

          for (const part of srcsetParts) {
            const [url, width] = part.trim().split(" ");
            if (width) {
              const numWidth = parseInt(width.replace("w", ""));
              if (numWidth > largestWidth) {
                largestWidth = numWidth;
                largestImage = url;
              }
            }
          }

          if (largestImage) {
            result.imageUrl = FormatUtils.makeUrlAbsolute(largestImage);
            Logger.debug(`Found Zara image from srcset: ${result.imageUrl}`);
            return;
          }
        }

        // Fallback to regular src attribute
        const src = imageElement.getAttribute("src");
        if (src) {
          result.imageUrl = FormatUtils.makeUrlAbsolute(src);
          Logger.debug(`Found Zara image: ${result.imageUrl}`);
          return;
        }

        // Last resort - try data-src for lazy-loaded images
        const dataSrc = imageElement.getAttribute("data-src");
        if (dataSrc) {
          result.imageUrl = FormatUtils.makeUrlAbsolute(dataSrc);
          Logger.debug(`Found Zara image from data-src: ${result.imageUrl}`);
          return;
        }
      }

      // If we still don't have an image, try to find any large image
      const bestImage = DOMUtils.findLargestImage();
      if (bestImage) {
        result.imageUrl = FormatUtils.makeUrlAbsolute(
          bestImage.getAttribute("src") || bestImage.getAttribute("data-src")
        );
        Logger.debug(
          `Found Zara image using findLargestImage: ${result.imageUrl}`
        );
      }
    } catch (e) {
      Logger.warn("Error extracting Zara product image", e);
    }
  },

  // Helper method to extract Zara-specific colors - based on the provided HTML structure
  extractZaraColors: function () {
    try {
      Logger.info("Extracting Zara-specific colors");
      const colorResults = [];

      // First try the color selector from the provided HTML
      const colorSelector = ".product-detail-color-selector__colors";
      const colorContainer = document.querySelector(colorSelector);

      if (colorContainer) {
        const colorItems = colorContainer.querySelectorAll(
          ".product-detail-color-selector__color"
        );
        Logger.debug(`Found ${colorItems.length} Zara color options`);

        for (const colorItem of colorItems) {
          // Check if this color is selected
          const isSelected = !!colorItem.querySelector(
            ".product-detail-color-selector__color-button--is-selected"
          );

          // Get color area to extract the RGB value
          const colorArea = colorItem.querySelector(
            ".product-detail-color-selector__color-area"
          );
          if (!colorArea) continue;

          // Try to get color name from screen reader text
          const screenReaderText = colorItem.querySelector(
            ".screen-reader-text"
          );
          let colorName = screenReaderText
            ? DOMUtils.getTextContent(screenReaderText)
            : "";

          // If no name found, try to get it from other potential sources
          if (!colorName) {
            // Check for aria label on the button
            const colorButton = colorItem.querySelector("button");
            if (colorButton) {
              colorName = colorButton.getAttribute("aria-label") || "";
            }
          }

          // Extract RGB color from the style attribute
          let colorValue = "";
          const styleAttr = colorArea.getAttribute("style");
          if (styleAttr) {
            const rgbMatch = styleAttr.match(/background-color:\s*([^;]+)/);
            if (rgbMatch && rgbMatch[1]) {
              colorValue = rgbMatch[1].trim();
            }
          }

          // If we have either a name or color value, add to variants
          if (colorName || colorValue) {
            // If we have no name but have a color value, create a generic name
            if (!colorName && colorValue) {
              colorName = this.generateColorNameFromRgb(colorValue);
            }

            colorResults.push({
              text: colorName || "Color Option",
              selected: isSelected,
              value: colorValue || colorName,
            });

            Logger.debug(
              `Added Zara color: ${colorName}, RGB: ${colorValue}, selected: ${isSelected}`
            );
          }
        }

        // Successfully extracted colors
        if (colorResults.length > 0) {
          return colorResults;
        }
      }

      // If the first method failed, try alternative selectors
      const alternativeColorSelectors = [
        ".product-colors .product-color-selector__colors", // Another potential structure
        ".color-selector-options", // Older Zara sites
      ];

      for (const selector of alternativeColorSelectors) {
        const colorItems = document.querySelectorAll(`${selector} > li`);
        if (colorItems && colorItems.length > 0) {
          Logger.debug(
            `Found ${colorItems.length} color options with alternative selector: ${selector}`
          );

          for (const colorItem of colorItems) {
            // Check if this color is selected
            const isSelected =
              colorItem.classList.contains("is-selected") ||
              colorItem.classList.contains("selected") ||
              !!colorItem.querySelector(".selected") ||
              !!colorItem.querySelector('[aria-selected="true"]');

            // Try different methods to get the color name
            let colorName = "";

            // Try aria-label first
            const button = colorItem.querySelector("button");
            if (button) {
              colorName = button.getAttribute("aria-label") || "";
            }

            // Try any element with a title attribute
            if (!colorName) {
              const titleElement = colorItem.querySelector("[title]");
              if (titleElement) {
                colorName = titleElement.getAttribute("title") || "";
              }
            }

            // Try any inner text
            if (!colorName) {
              colorName = DOMUtils.getTextContent(colorItem);
            }

            // Try to extract color from background style
            let colorValue = "";
            const colorBlock = colorItem.querySelector('[style*="background"]');
            if (colorBlock) {
              const styleAttr = colorBlock.getAttribute("style");
              if (styleAttr) {
                const bgMatch = styleAttr.match(
                  /background(?:-color)?:\s*([^;]+)/
                );
                if (bgMatch && bgMatch[1]) {
                  colorValue = bgMatch[1].trim();
                }
              }
            }

            // Add to color variants if we have enough info
            if (colorName || colorValue) {
              // Generate name from color value if needed
              if (!colorName && colorValue) {
                colorName = this.generateColorNameFromRgb(colorValue);
              }

              colorResults.push({
                text: colorName || "Color Option",
                selected: isSelected,
                value: colorValue || colorName,
              });

              Logger.debug(
                `Added Zara color (alternative): ${colorName}, value: ${colorValue}`
              );
            }
          }

          // If we found colors, stop searching
          if (colorResults.length > 0) {
            break;
          }
        }
      }

      return colorResults;
    } catch (e) {
      Logger.warn("Error extracting Zara colors", e);
      return [];
    }
  },

  // Helper to generate a color name from RGB value
  generateColorNameFromRgb: function (rgbValue) {
    // Parse RGB values
    const rgbMatch = rgbValue.match(
      /rgb\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)/
    );
    if (!rgbMatch) return "Color";

    const r = parseInt(rgbMatch[1], 10);
    const g = parseInt(rgbMatch[2], 10);
    const b = parseInt(rgbMatch[3], 10);

    // Simple algorithm to identify basic colors
    if (r > 200 && g > 200 && b > 200) return "White";
    if (r < 50 && g < 50 && b < 50) return "Black";

    if (r > 180 && g < 100 && b < 100) return "Red";
    if (r < 100 && g > 180 && b < 100) return "Green";
    if (r < 100 && g < 100 && b > 180) return "Blue";

    if (r > 180 && g > 180 && b < 100) return "Yellow";
    if (r > 180 && g < 100 && b > 180) return "Purple";
    if (r < 100 && g > 180 && b > 180) return "Cyan";

    if (r > 180 && g > 100 && b < 100) return "Orange";
    if (r > 100 && g < 100 && b > 100) return "Purple";
    if (r > 100 && g > 100 && b < 100) return "Brown";

    // Default for gray tones
    if (Math.abs(r - g) < 30 && Math.abs(g - b) < 30 && Math.abs(r - b) < 30) {
      return r < 150 ? "Dark Gray" : "Light Gray";
    }

    return "Color";
  },

  // Helper method to extract Zara-specific sizes - based on the provided HTML structure
  extractZaraSizes: function () {
    try {
      Logger.info("Extracting Zara-specific sizes");
      const sizeResults = [];

      // First try the size selector from the provided HTML structure
      const sizeSelector = ".size-selector-sizes";
      const sizeContainer = document.querySelector(sizeSelector);

      if (sizeContainer) {
        // Get all size elements
        const sizeItems = sizeContainer.querySelectorAll(
          ".size-selector-sizes__size"
        );
        Logger.debug(`Found ${sizeItems.length} Zara size options`);

        for (const sizeItem of sizeItems) {
          // Check if this size is enabled (in stock)
          const isEnabled = !sizeItem.classList.contains(
            "size-selector-sizes-size--disabled"
          );

          // Get size label
          const sizeLabel = sizeItem.querySelector(
            ".size-selector-sizes-size__label"
          );
          if (!sizeLabel) continue;

          const sizeText = DOMUtils.getTextContent(sizeLabel);
          if (!sizeText) continue;

          // Check if this size is selected
          const isSelected =
            sizeItem.classList.contains("selected") ||
            sizeItem.classList.contains("size-selector-sizes-size--selected") ||
            !!sizeItem.querySelector('[aria-selected="true"]');

          // Create a JSON string value that includes the inStock information
          // This is the key change - we're formatting the value as a JSON string that can be parsed by Dart
          const valueObj = {
            size: sizeText,
            inStock: isEnabled,
          };
          const valueJson = JSON.stringify(valueObj);

          // Add to size variants
          sizeResults.push({
            text: sizeText,
            selected: isSelected,
            value: valueJson, // Store as JSON string so Dart can parse it
          });

          Logger.debug(
            `Added Zara size: ${sizeText}, in stock: ${isEnabled}, selected: ${isSelected}`
          );
        }

        // Successfully extracted sizes
        if (sizeResults.length > 0) {
          return sizeResults;
        }
      }

      // Try alternative size selectors if the first method failed
      const alternativeSizeSelectors = [
        ".product-size-selector .product-size-info-name",
        ".size-selector-option",
        ".product-sizes [data-qa-option]",
      ];

      for (const selector of alternativeSizeSelectors) {
        const sizeItems = document.querySelectorAll(selector);
        if (sizeItems && sizeItems.length > 0) {
          Logger.debug(
            `Found ${sizeItems.length} size options with alternative selector: ${selector}`
          );

          for (const sizeItem of sizeItems) {
            // Check attributes to determine if this size is in stock
            const isEnabled =
              !sizeItem.hasAttribute("disabled") &&
              !sizeItem.classList.contains("disabled") &&
              !sizeItem.classList.contains("product-size--out-of-stock");

            // Get size text - try multiple approaches
            let sizeText = DOMUtils.getTextContent(sizeItem);

            // If the element itself doesn't have text, look for a child element
            if (!sizeText) {
              const sizeLabel = sizeItem.querySelector(
                ".size-name, .size-label, [data-qa-size]"
              );
              if (sizeLabel) {
                sizeText = DOMUtils.getTextContent(sizeLabel);
              }
            }

            if (!sizeText) continue;

            // Check if this size is selected
            const isSelected =
              sizeItem.classList.contains("selected") ||
              sizeItem.classList.contains("product-size--is-selected") ||
              (sizeItem.hasAttribute("aria-selected") &&
                sizeItem.getAttribute("aria-selected") === "true");

            // Create a JSON string value that includes the inStock information
            const valueObj = {
              size: sizeText,
              inStock: isEnabled,
            };
            const valueJson = JSON.stringify(valueObj);

            // Add to size variants
            sizeResults.push({
              text: sizeText,
              selected: isSelected,
              value: valueJson,
            });

            Logger.debug(
              `Added Zara size (alternative): ${sizeText}, in stock: ${isEnabled}`
            );
          }

          // If we found sizes, stop searching
          if (sizeResults.length > 0) {
            break;
          }
        }
      }

      // If we still didn't find sizes, try one more approach - look for a hidden size selector
      if (sizeResults.length === 0) {
        // Try to find the size button which might open the size selector
        const sizeButton = document.querySelector(
          'button[data-qa-action="open-size-selector"]'
        );
        if (sizeButton) {
          Logger.debug(
            'Found "Add" button for size selection, but sizes may be hidden'
          );

          // Even though the size selector might be hidden, the elements could still be in the DOM
          const hiddenSizes = document.querySelectorAll(
            '.size-selector-sizes-size__label, [data-qa-qualifier="size-selector-sizes-size-label"]'
          );

          if (hiddenSizes && hiddenSizes.length > 0) {
            Logger.debug(
              `Found ${hiddenSizes.length} potentially hidden size elements`
            );

            for (const sizeElem of hiddenSizes) {
              const sizeText = DOMUtils.getTextContent(sizeElem);
              if (!sizeText) continue;

              // For hidden sizes, we can't determine if they're selected
              // We assume they're in stock unless otherwise indicated
              const sizeContainer = sizeElem.closest(
                "li, .size-selector-sizes-size"
              );
              const isEnabled = sizeContainer
                ? !sizeContainer.classList.contains("disabled") &&
                  !sizeContainer.classList.contains("out-of-stock")
                : true;

              // Create a JSON string value that includes the inStock information
              const valueObj = {
                size: sizeText,
                inStock: isEnabled,
              };
              const valueJson = JSON.stringify(valueObj);

              sizeResults.push({
                text: sizeText,
                selected: false, // Can't determine for hidden sizes
                value: valueJson,
              });

              Logger.debug(`Added Zara hidden size: ${sizeText}`);
            }
          }
        }
      }

      return sizeResults;
    } catch (e) {
      Logger.warn("Error extracting Zara sizes", e);
      return [];
    }
  },
};

// Stradivarius Extractor - Add this after other site-specific extractors
const StradivariusExtractor = {
  // Check if current site is Stradivarius
  isStradivarius: function() {
    const url = window.location.href.toLowerCase();
    return url.includes("stradivarius.com");
  },
  
  // Extract product information from Stradivarius pages
  extract: function() {
    try {
      Logger.info("Extracting product data for Stradivarius");
      
      // Basic product information
      const productInfo = {
        isProductPage: true,
        success: false,
        brand: "Stradivarius",
        url: window.location.href,
        currency: "TRY", // Default to TRY, will try to extract actual currency
        extractionMethod: "stradivarius-specific",
      };
      
      // Extract title - Stradivarius usually has a h1 for product title
      const titleElement = document.querySelector("h1");
      if (titleElement) {
        productInfo.title = titleElement.textContent.trim();
      }
      
      // Extract price
      // Look for price with various selectors specific to Stradivarius
      const priceSelectors = [
        '.product-price', 
        '[data-testid="price"]',
        '[data-qa-id="current-price"]',
        '.price-current-amount',
        '.actual-price'
      ];
      
      for (const selector of priceSelectors) {
        const priceElement = document.querySelector(selector);
        if (priceElement && priceElement.textContent) {
          // Process the price text to extract the number and currency
          const priceText = priceElement.textContent.trim();
          Logger.debug(`Found price: ${priceText}`);
          
          // Extract currency and numeric value
          const currencyMatch = priceText.match(/(TRY|\$|€|£|₺)/);
          if (currencyMatch) {
            const currencyMap = {
              "TRY": "TRY",
              "₺": "TRY",
              "$": "USD",
              "€": "EUR",
              "£": "GBP"
            };
            productInfo.currency = currencyMap[currencyMatch[1]] || "TRY";
          }
          
          // Extract numeric price
          const priceMatch = priceText.match(/[\d,.]+/);
          if (priceMatch) {
            // Handle different price formats (1.234,56 or 1,234.56)
            let priceValue = priceMatch[0];
            // If price contains both comma and period, handle Turkish format
            if (priceValue.includes(',') && priceValue.includes('.')) {
              // Remove periods (thousand separators) and replace comma with period
              priceValue = priceValue.replace(/\./g, '').replace(',', '.');
            } else if (priceValue.includes(',')) {
              // If only comma exists, treat it as decimal separator
              priceValue = priceValue.replace(',', '.');
            }
            productInfo.price = parseFloat(priceValue);
            
            // Mark as successful if we have both title and price
            if (productInfo.title) {
              productInfo.success = true;
            }
          }
          break; // Stop after finding first valid price
        }
      }
      
      // Extract product image
      // Stradivarius uses different image selectors, try them all
      const imageSelectors = [
        'img.multimedia-item-fade-in', // From the HTML you provided
        '.multimedia-list-container img',
        '.product-detail-image img',
        '.multimedia-item.image img',
        '[data-cy^="horizontal-image"] img',
        '.product-images-container img'
      ];
      
      for (const selector of imageSelectors) {
        const images = document.querySelectorAll(selector);
        if (images && images.length > 0) {
          // Get the first image, which is usually the main product image
          const mainImage = images[0];
          if (mainImage.src) {
            Logger.debug(`Found image: ${mainImage.src}`);
            productInfo.imageUrl = mainImage.src;
            break;
          }
        }
      }
      
      // Extract color variants
      const colorVariants = [];
      // Updated selectors for Stradivarius colors - focusing on images in color lists
      const colorSelectors = [
        '.color-selector-container .color-item img',
        '.colors-list .color-item img',
        '.color-lists img',
        '.product-colors .color-button img'
      ];
      
      for (const selector of colorSelectors) {
        const colorElements = document.querySelectorAll(selector);
        if (colorElements && colorElements.length > 0) {
          // Process each color variant
          colorElements.forEach(colorElement => {
            // Get color name from alt attribute
            let colorName = colorElement.getAttribute('alt');
            
            // Skip if no alt text or it's a social media icon
            const socialMediaTerms = ['facebook', 'instagram', 'twitter', 'youtube', 'pinterest', 'tiktok', 'linkedin', 'preference', 'privacy', 'company logo', 'ios', 'android'];
            const isSocialMedia = !colorName || socialMediaTerms.some(term => 
              colorName.toLowerCase().includes(term));
              
            if (colorName && !isSocialMedia) {
              // Check if this color's parent element is selected
              const colorItem = colorElement.closest('.color-item');
              const isSelected = colorItem && (
                colorItem.classList.contains('selected') || 
                colorItem.hasAttribute('aria-selected') || 
                colorItem.classList.contains('active') ||
                colorItem.querySelector('.color-selected') !== null
              );
              
              // Use the image source URL as the value
              const imageUrl = colorElement.getAttribute('src');
              
              // Add to color variants
              colorVariants.push({
                text: colorName,
                selected: isSelected,
                value: imageUrl // Use the image URL so we can display the color swatch
              });
              Logger.debug(`Added color variant: ${colorName}`);
            }
          });
          
          if (colorVariants.length > 0) {
            break; // Stop after finding color variants with one selector
          }
        }
      }
      
      // Extract size variants
      const sizeVariants = [];
      // Stradivarius uses various selectors for size options
      const sizeSelectors = [
        '.size-selector-container .size-item',
        '.size-selector .size-option',
        '.product-sizes .size-button',
        '[data-qa-id="sizes"] button',
        '.size-selector-sizes__size'
      ];
      
      for (const selector of sizeSelectors) {
        const sizeElements = document.querySelectorAll(selector);
        if (sizeElements && sizeElements.length > 0) {
          // Process each size variant
          sizeElements.forEach(sizeElement => {
            // Try to get size name from various sources
            let sizeText = '';
            
            // Try to find the text in a label element
            const sizeLabel = sizeElement.querySelector('.size-label, .size-text, .size-selector-sizes-size__label');
            if (sizeLabel && sizeLabel.textContent.trim()) {
              sizeText = sizeLabel.textContent.trim();
            }
            // Try aria-label
            else if (sizeElement.getAttribute('aria-label')) {
              sizeText = sizeElement.getAttribute('aria-label');
            }
            // Try inner text as fallback
            else if (sizeElement.textContent.trim()) {
              sizeText = sizeElement.textContent.trim();
            }
            
            if (sizeText) {
              // Check if size is in stock
              const isDisabled = sizeElement.classList.contains('disabled') || 
                              sizeElement.classList.contains('out-of-stock') ||
                              sizeElement.classList.contains('size-selector-sizes-size--disabled') ||
                              sizeElement.hasAttribute('disabled');
                              
              const isSelected = sizeElement.classList.contains('selected') || 
                               sizeElement.hasAttribute('aria-selected') ||
                               sizeElement.classList.contains('size-selector-sizes-size--selected') ||
                               !!sizeElement.querySelector('[aria-selected="true"]');
              
              // Create value object with stock info
              const valueObj = {
                size: sizeText,
                inStock: isEnabled,
              };
              
              // Add to size variants
              sizeVariants.push({
                text: sizeText,
                selected: isSelected,
                value: JSON.stringify(valueObj)
              });
              Logger.debug(`Added size variant: ${sizeText} (in stock: ${isEnabled})`);
            }
          });
          
          if (sizeVariants.length > 0) {
            break; // Stop after finding size variants with one selector
          }
        }
      }
      
      // Add variants to product info if found
      if (colorVariants.length > 0 || sizeVariants.length > 0) {
        productInfo.variants = {};
        if (colorVariants.length > 0) {
          productInfo.variants.colors = colorVariants;
        }
        if (sizeVariants.length > 0) {
          productInfo.variants.sizes = sizeVariants;
        }
      }
      
      // Extract description
      const descriptionSelectors = [
        '.product-description pre',
        '.product-description',
        '.description-content',
        '[data-qa-id="description"]'
      ];
      
      for (const selector of descriptionSelectors) {
        const descriptionElement = document.querySelector(selector);
        if (descriptionElement && descriptionElement.textContent.trim()) {
          productInfo.description = descriptionElement.textContent.trim();
          break;
        }
      }
      
      return productInfo;
    } catch (e) {
      Logger.error("Error extracting Stradivarius product data", e);
      return {
        isProductPage: true,
        success: false,
        brand: "Stradivarius",
        url: window.location.href,
        extractionMethod: "stradivarius-specific-failed",
        error: e.message
      };
    }
  }
};

// Cartier Extractor - For extracting Cartier product information
const CartierExtractor = {
  // Check if current site is Cartier
  isCartier: function() {
    const url = window.location.href.toLowerCase();
    return url.includes("cartier.com");
  },
  
  // Extract product information from Cartier pages
  extract: function() {
    try {
      Logger.info("Extracting product data for Cartier");
      
      // Basic product information
      const result = BaseExtractor.createResultObject();
      result.brand = "Cartier";
      result.extractionMethod = "cartier-specific";
      
      // Extract title
      const titleSelectors = [
        '.ProductInfo-title', // Primary selector
        'h1.ProductTitle',
        '.product-title h1',
        'h1.title'
      ];
      
      const titleElement = DOMUtils.querySelector(titleSelectors);
      if (titleElement) {
        result.title = DOMUtils.getTextContent(titleElement);
        Logger.debug(`Found Cartier title: ${result.title}`);
      }
      
      // Extract price
      const priceSelectors = [
        '.ProductInfo-price', // Primary selector
        '.product-price',
        '.price .value',
        '[data-element="price"]',
        '[itemprop="price"]'
      ];
      
      const priceElement = DOMUtils.querySelector(priceSelectors);
      if (priceElement) {
        const priceText = DOMUtils.getTextContent(priceElement);
        result.price = FormatUtils.formatPrice(priceText);
        result.currency = FormatUtils.detectCurrency(priceText);
        Logger.debug(`Found Cartier price: ${result.price} ${result.currency}`);
      }
      
      // Extract product image
      const imageSelectors = [
        '.ProductGallery img',
        '.product-image img',
        '[data-element="product-image"] img',
        '[itemprop="image"]'
      ];
      
      const imageElement = DOMUtils.querySelector(imageSelectors);
      if (imageElement && imageElement.getAttribute('src')) {
        result.imageUrl = FormatUtils.makeUrlAbsolute(imageElement.getAttribute('src'));
        Logger.debug(`Found Cartier image: ${result.imageUrl}`);
      }
      
      // Extract product description
      const descriptionSelectors = [
        '.ProductInfo-description',
        '.product-description',
        '[itemprop="description"]',
        '[data-element="description"]'
      ];
      
      const descriptionElement = DOMUtils.querySelector(descriptionSelectors);
      if (descriptionElement) {
        result.description = DOMUtils.getTextContent(descriptionElement);
        Logger.debug("Found Cartier description");
      }
      
      // Extract product SKU/Reference
      // For Cartier, extract the product code from the URL (e.g., CRH4414200)
      const skuMatch = window.location.pathname.match(/[A-Z0-9]{5,}(?=\.html)/);
      if (skuMatch) {
        result.sku = skuMatch[0];
        Logger.debug(`Extracted Cartier SKU from URL: ${result.sku}`);
      }
      
      // Try to find a reference code in the DOM as a backup
      const skuSelectors = [
        '.product-reference',
        '.reference-number',
        '[data-element="reference"]'
      ];
      
      const skuElement = DOMUtils.querySelector(skuSelectors);
      if (skuElement && !result.sku) {
        result.sku = DOMUtils.getTextContent(skuElement).replace(/Ref.:|Reference:|Ref:/i, '').trim();
        Logger.debug(`Found Cartier SKU in DOM: ${result.sku}`);
      }
      
      // Mark as success if we have the essential product information
      if (result.title && result.price) {
        result.success = true;
        Logger.info("Successfully extracted Cartier product data");
      }
      
      return result;
    } catch (e) {
      Logger.error("Error extracting Cartier product data", e);
      return {
        isProductPage: true,
        success: false,
        brand: "Cartier",
        url: window.location.href,
        extractionMethod: "cartier-specific",
        error: e.message
      };
    }
  }
};

// Swarovski Extractor - For extracting Swarovski product information
const SwarovskiExtractor = {
  // Check if current site is Swarovski
  isSwarovski: function() {
    const url = window.location.href.toLowerCase();
    return url.includes("swarovski.com");
  },
  
  // Extract product information from Swarovski pages
  extract: function() {
    try {
      Logger.info("Extracting product data for Swarovski");
      
      // Basic product information
      const result = BaseExtractor.createResultObject();
      result.brand = "Swarovski";
      result.extractionMethod = "swarovski-specific";
      
      // Extract title
      const titleSelectors = [
        '.product-name h1', 
        '.swa-product-basic-info__title',
        '.swa-product-overview-title',
        '.product-detail-title'
      ];
      
      const titleElement = DOMUtils.querySelector(titleSelectors);
      if (titleElement) {
        result.title = DOMUtils.getTextContent(titleElement);
        Logger.debug(`Found Swarovski title: ${result.title}`);
      }
      
      // Extract price
      const priceSelectors = [
        '.swa-product-summary__price', 
        '.price-sales',
        '.product-price .value',
        '[data-test-id="product-sales-price"]'
      ];
      
      const priceElement = DOMUtils.querySelector(priceSelectors);
      if (priceElement) {
        const priceText = DOMUtils.getTextContent(priceElement);
        result.price = FormatUtils.formatPrice(priceText);
        result.currency = FormatUtils.detectCurrency(priceText);
        Logger.debug(`Found Swarovski price: ${result.price} ${result.currency}`);
      }

      // Extract original price if available (for sale items)
      const originalPriceSelectors = [
        '.price-standard',
        '.swa-product-summary__price--original',
        '[data-test-id="product-standard-price"]'
      ];

      const originalPriceElement = DOMUtils.querySelector(originalPriceSelectors);
      if (originalPriceElement) {
        const originalPriceText = DOMUtils.getTextContent(originalPriceElement);
        result.originalPrice = FormatUtils.formatPrice(originalPriceText);
        Logger.debug(`Found Swarovski original price: ${result.originalPrice}`);
      }
      
      // Extract product image
      const imageSelectors = [
        '.carousel-item.active img',
        '.swa-product-gallery-carousel__main-image img',
        '.swa-product-gallery img',
        '[data-test-id="product-image"] img'
      ];
      
      const imageElement = DOMUtils.querySelector(imageSelectors);
      if (imageElement) {
        let imageUrl = imageElement.getAttribute('src');
        // Try to get larger image from data attributes if available
        if (!imageUrl || imageUrl.includes('transparent.gif')) {
          imageUrl = imageElement.getAttribute('data-src') || 
                     imageElement.getAttribute('data-zoom-image') || 
                     imageElement.getAttribute('data-large-img');
        }
        if (imageUrl) {
          result.imageUrl = FormatUtils.makeUrlAbsolute(imageUrl);
          Logger.debug(`Found Swarovski image: ${result.imageUrl}`);
        }
      }
      
      // Extract product description
      const descriptionSelectors = [
        '.product-details-description',
        '.swa-product-content-details__description',
        '.swa-product-details__description',
        '[data-test-id="product-description"]'
      ];
      
      const descriptionElement = DOMUtils.querySelector(descriptionSelectors);
      if (descriptionElement) {
        result.description = DOMUtils.getTextContent(descriptionElement);
        Logger.debug("Found Swarovski description");
      }
      
      // Extract product SKU/ID
      // For Swarovski, we can extract the product code from the URL (e.g., 5642595)
      const skuMatch = window.location.pathname.match(/\/p-[A-Za-z](\d+)\//);
      if (skuMatch && skuMatch[1]) {
        result.sku = skuMatch[1];
        Logger.debug(`Extracted Swarovski SKU from URL: ${result.sku}`);
      } else {
        // Try to find SKU in the DOM
        const skuSelectors = [
          '.product-id',
          '.swa-product-number',
          '[data-test-id="product-id"]'
        ];
        
        const skuElement = DOMUtils.querySelector(skuSelectors);
        if (skuElement) {
          result.sku = DOMUtils.getTextContent(skuElement).replace(/Item No.:|Art. Nr.:|Ref:/i, '').trim();
          Logger.debug(`Found Swarovski SKU in DOM: ${result.sku}`);
        }
      }
      
      // Extract colors - Swarovski specific
      this.extractSwarovskiColors(result);
      
      // Mark as success if we have the essential product information
      if (result.title && result.price) {
        result.success = true;
        Logger.info("Successfully extracted Swarovski product data");
      }
      
      return result;
    } catch (e) {
      Logger.error("Error extracting Swarovski product data", e);
      return {
        isProductPage: true,
        success: false,
        brand: "Swarovski",
        url: window.location.href,
        extractionMethod: "swarovski-specific",
        error: e.message
      };
    }
  },
  
  // Extract color variants specifically for Swarovski
  extractSwarovskiColors: function(result) {
    try {
      Logger.info("Extracting Swarovski color variants");
      
      // Swarovski color variants are in a specific container
      const colorContainer = document.querySelector('.swa-product-color-selector-horizontal__tiles');
      
      if (colorContainer) {
        const colorItems = colorContainer.querySelectorAll('.swa-product-color-variant-thumbnail');
        Logger.debug(`Found ${colorItems.length} Swarovski color options`);
        
        if (colorItems && colorItems.length > 0) {
          for (const colorItem of colorItems) {
            // Check if this color is selected
            const isSelected = colorItem.classList.contains('swa-product-color-variant-thumbnail--selected');
            
            // Get color link and name
            const colorLink = colorItem.querySelector('a');
            if (!colorLink) continue;
            
            // Get color name from name attribute
            let colorName = colorLink.getAttribute('name');
            if (!colorName) {
              colorName = colorLink.getAttribute('aria-label');
              if (colorName && colorName.startsWith('Product: ')) {
                colorName = colorName.substring('Product: '.length);
              }
            }
            
            if (!colorName) continue;
            
            // Get the image URL for the color
            const img = colorItem.querySelector('img');
            let imageUrl = null;
            
            if (img) {
              // Get image URL
              imageUrl = FormatUtils.makeUrlAbsolute(img.getAttribute('src'));
            }
            
            // Add to color variants
            result.variants.colors.push({
              text: colorName,
              selected: isSelected,
              value: imageUrl || colorName // Use image URL as value if available
            });
            
            Logger.debug(`Added Swarovski color: ${colorName}, selected: ${isSelected}`);
          }
        }
      }
      
      // If no colors found from main selector, try alternative selectors
      if (result.variants.colors.length === 0) {
        const alternativeSelectors = [
          '.swa-swatches-container .swa-swatch',
          '.swa-product-variants .swa-variant-selector',
          '.swa-product-color-selector .swa-color-selector-item'
        ];
        
        for (const selector of alternativeSelectors) {
          const colorElements = document.querySelectorAll(selector);
          
          if (colorElements && colorElements.length > 0) {
            Logger.debug(`Found ${colorElements.length} color options with alternative selector: ${selector}`);
            
            for (const element of colorElements) {
              // Check if selected
              const isSelected = element.classList.contains('selected') || 
                               element.classList.contains('active') ||
                               element.getAttribute('aria-selected') === 'true';
              
              // Get color name from various possible sources
              let colorName = element.getAttribute('title') || 
                            element.getAttribute('data-color-name') || 
                            element.getAttribute('aria-label');
              
              if (!colorName) {
                const nameEl = element.querySelector('.color-name, .swatch-name');
                if (nameEl) {
                  colorName = DOMUtils.getTextContent(nameEl);
                }
              }
              
              if (!colorName) continue;
              
              // Get image if available
              const img = element.querySelector('img');
              let imageUrl = null;
              
              if (img && img.src) {
                imageUrl = FormatUtils.makeUrlAbsolute(img.src);
              }
              
              // Add to color variants
              result.variants.colors.push({
                text: colorName,
                selected: isSelected,
                value: imageUrl || colorName
              });
              
              Logger.debug(`Added Swarovski color (alternative): ${colorName}`);
            }
            
            if (result.variants.colors.length > 0) {
              break; // Stop after finding colors with one selector
            }
          }
        }
      }
    } catch (e) {
      Logger.warn("Error extracting Swarovski colors", e);
    }
  }
};

// Guess Extractor - For extracting Guess product information
const GuessExtractor = {
  // Check if current site is Guess
  isGuess: function() {
    const url = window.location.href.toLowerCase();
    return url.includes("guess.eu");
  },
  
  // Extract product information from Guess pages
  extract: function() {
    try {
      Logger.info("Extracting product data for Guess");
      
      // Basic product information
      const result = BaseExtractor.createResultObject();
      result.brand = "Guess";
      result.extractionMethod = "guess-specific";
      
      // Extract title
      const titleSelectors = [
        '.product-name h1',
        '.pdp-details__name h1',
        '.product-detail-name'
      ];
      
      const titleElement = DOMUtils.querySelector(titleSelectors);
      if (titleElement) {
        result.title = DOMUtils.getTextContent(titleElement);
        Logger.debug(`Found Guess title: ${result.title}`);
      } else {
        // Fallback to page title
        const pageTitle = document.title;
        if (pageTitle) {
          // Often follows pattern: "Product Name | Guess"
          const titleParts = pageTitle.split("|");
          if (titleParts.length > 1) {
            result.title = titleParts[0].trim();
          } else {
            result.title = pageTitle;
          }
          Logger.debug(`Using page title: ${result.title}`);
        }
      }
      
      // Extract price
      const priceSelectors = [
        '.product-price .price-sales',
        '.price-sales',
        '.product-price .value',
        '[data-sales-price]'
      ];
      
      const priceElement = DOMUtils.querySelector(priceSelectors);
      if (priceElement) {
        const priceText = DOMUtils.getTextContent(priceElement);
        result.price = FormatUtils.formatPrice(priceText);
        result.currency = FormatUtils.detectCurrency(priceText);
        Logger.debug(`Found Guess price: ${result.price} ${result.currency}`);
      }
      
      // Extract original price (for sales)
      const originalPriceSelectors = [
        '.product-price .price-standard',
        '.price-standard',
        '.product-price .strike-through'
      ];
      
      const originalPriceElement = DOMUtils.querySelector(originalPriceSelectors);
      if (originalPriceElement) {
        const originalPriceText = DOMUtils.getTextContent(originalPriceElement);
        result.originalPrice = FormatUtils.formatPrice(originalPriceText);
        Logger.debug(`Found Guess original price: ${result.originalPrice}`);
      }
      
      // Extract product image
      const imageSelectors = [
        '.pdp-primary-image img',
        '.product-image img',
        '.primary-image img'
      ];
      
      const imageElement = DOMUtils.querySelector(imageSelectors);
      if (imageElement) {
        const imageSrc = imageElement.src || imageElement.getAttribute('data-src');
        if (imageSrc) {
          result.imageUrl = FormatUtils.makeUrlAbsolute(imageSrc);
          Logger.debug(`Found Guess image: ${result.imageUrl}`);
        }
      }
      
      // Extract product description
      const descriptionSelectors = [
        '.product-description',
        '.product-detail-description',
        '.pdp-details__description'
      ];
      
      const descriptionElement = DOMUtils.querySelector(descriptionSelectors);
      if (descriptionElement) {
        result.description = DOMUtils.getTextContent(descriptionElement);
        Logger.debug(`Found Guess description`);
      }
      
      // Extract product SKU
      const skuSelectors = [
        '.product-id',
        '.product-detail-sku',
        '[data-target="#product-sku"]'
      ];
      
      const skuElement = DOMUtils.querySelector(skuSelectors);
      if (skuElement) {
        result.sku = DOMUtils.getTextContent(skuElement).replace(/SKU:|Ref:|\s+/gi, '');
        Logger.debug(`Found Guess SKU: ${result.sku}`);
      }
      
      // Extract color variants 
      this.extractGuessColors(result);
      
      // Extract size variants
      this.extractGuessSizes(result);
      
      // Check if we have the minimum needed information for success
      result.success = !!(result.title && result.price);
      
      // Execute additional script to enhance variants after returning the basic data
      setTimeout(() => {
        try {
          if (window.FlutterChannel) {
            const enhancedScript = this.getEnhancedVariantsScript();
            eval(enhancedScript);
          }
        } catch (e) {
          Logger.error("Error executing enhanced variants script", e);
        }
      }, 500);
      
      return result;
    } catch (e) {
      Logger.error("Error extracting Guess product data", e);
      return {
        isProductPage: true,
        success: false,
        brand: "Guess",
        url: window.location.href,
        extractionMethod: "guess-specific",
        error: e.message
      };
    }
  },
  
  // Extract color information specific to Guess
  extractGuessColors: function(result) {
    try {
      Logger.info("Extracting Guess color options");
      
      // Find the color swatches container
      const colorSwatchContainer = document.querySelector('.swatches-wrapper, .color-swatches');
      
      if (colorSwatchContainer) {
        const colorButtons = colorSwatchContainer.querySelectorAll('button.color-attribute');
        
        Logger.debug(`Found ${colorButtons.length} color options for Guess`);
        
        for (const button of colorButtons) {
          const colorSwatch = button.querySelector('.color-value');
          
          if (colorSwatch) {
            // Extract color code (identifier)
            const colorCode = colorSwatch.getAttribute('data-attr-value');
            
            // Extract color name
            const colorName = colorSwatch.getAttribute('data-attr-name');
            
            // Extract image URL if available
            let colorImage = '';
            const style = colorSwatch.getAttribute('style');
            if (style && style.includes('background-image')) {
              const bgImgMatch = style.match(/background-image\s*:\s*url\(['"]?(.*?)['"]?\)/i);
              if (bgImgMatch && bgImgMatch[1]) {
                colorImage = bgImgMatch[1];
              }
            }
            
            // Check if selected
            const isSelected = button.classList.contains('attribute__value-wrapper--selected');
            
            // Check for selected indicator text
            const selectedText = button.querySelector('.selected-assistive-text');
            const hasSelectedText = selectedText && selectedText.textContent.trim() === 'selected';
            
            // Add to result
            if (colorName) {
              result.variants.colors.push({
                text: colorName,
                selected: isSelected || hasSelectedText || colorSwatch.classList.contains('selected'),
                value: colorImage || colorCode
              });
              
              Logger.debug(`Added Guess color: ${colorName}, selected: ${isSelected || hasSelectedText}`);
            }
          }
        }
      }
    } catch (e) {
      Logger.warn("Error extracting Guess color variants", e);
    }
  },
  
  // Extract size information specific to Guess
  extractGuessSizes: function(result) {
    try {
      Logger.info("Extracting Guess size options");
      
      // Find the size options container
      const sizeContainer = document.querySelector('.variation.single-size, .size-container');
      
      if (sizeContainer) {
        // Get size option wrappers first
        const sizeWrappers = sizeContainer.querySelectorAll('.attribute__value-wrapper');
        
        if (sizeWrappers && sizeWrappers.length > 0) {
          Logger.debug(`Found ${sizeWrappers.length} size wrappers for Guess`);
          
          for (const wrapper of sizeWrappers) {
            // Check if wrapper is hidden (out of stock or unavailable)
            const isHidden = wrapper.classList.contains('d-none');
            
            // Get the size button inside the wrapper
            const sizeButton = wrapper.querySelector('.attribute__btn');
            if (!sizeButton) continue;
            
            // Get size value
            const sizeValue = sizeButton.getAttribute('data-attr-value') || sizeButton.textContent.trim();
            if (!sizeValue) continue;
            
            // Check if the size is available
            const isAvailable = !isHidden && sizeButton.classList.contains('selectable') && 
                              !sizeButton.classList.contains('unselectable');
                             
            // Check if the size is selected
            const isSelected = sizeButton.classList.contains('selected') || 
                              sizeButton.getAttribute('aria-selected') === 'true';
            
            // Add size to result
            result.variants.sizes.push({
              text: sizeValue,
              selected: isSelected,
              value: JSON.stringify({ inStock: isAvailable })
            });
            
            Logger.debug(`Added Guess size: ${sizeValue}, available: ${isAvailable}, selected: ${isSelected}`);
          }
        } else {
          // Fallback to find direct size buttons
          const sizeButtons = sizeContainer.querySelectorAll('.attribute__btn');
          
          Logger.debug(`Found ${sizeButtons.length} size buttons for Guess`);
          
          for (const button of sizeButtons) {
            // Get size value
            const sizeValue = button.getAttribute('data-attr-value') || button.textContent.trim();
            if (!sizeValue) continue;
            
            // Check if the size is available
            const isAvailable = button.classList.contains('selectable') && 
                               !button.classList.contains('unselectable');
                               
            // Check if the size is selected
            const isSelected = button.classList.contains('selected') || 
                              button.getAttribute('aria-selected') === 'true';
            
            // Add size to result
            result.variants.sizes.push({
              text: sizeValue,
              selected: isSelected,
              value: JSON.stringify({ inStock: isAvailable })
            });
            
            Logger.debug(`Added Guess size: ${sizeValue}, available: ${isAvailable}, selected: ${isSelected}`);
          }
        }
      }
    } catch (e) {
      Logger.warn("Error extracting Guess size variants", e);
    }
  },
  
  // Get enhanced variants extraction script - this will be injected to get more accurate colors and sizes
  getEnhancedVariantsScript: function() {
    return `
      try {
        // Function to fetch Guess variants with more accuracy
        function fetchGuessVariants() {
          const results = { colors: [], sizes: [] };
          
          // Extract colors
          try {
            const colorContainer = document.querySelector(".swatches-wrapper, .color-swatches");
            if (colorContainer) {
              const colorButtons = colorContainer.querySelectorAll("button.color-attribute");
              
              for (let i = 0; i < colorButtons.length; i++) {
                const button = colorButtons[i];
                const colorSwatch = button.querySelector(".color-value");
                
                if (colorSwatch) {
                  // Get color code
                  const colorCode = colorSwatch.getAttribute("data-attr-value");
                  
                  // Get color name
                  const colorName = colorSwatch.getAttribute("data-attr-name");
                  
                  // Get image URL if available
                  let imageUrl = "";
                  const style = colorSwatch.getAttribute("style");
                  if (style && style.includes("background-image")) {
                    const match = style.match(/background-image\\s*:\\s*url\\(['"]?(.*?)['"]?\\)/i);
                    if (match && match[1]) {
                      imageUrl = match[1];
                    }
                  }
                  
                  // Check if selected
                  const isSelected = button.classList.contains("attribute__value-wrapper--selected");
                  
                  // Check for selected text
                  const selectedText = button.querySelector(".selected-assistive-text");
                  const hasSelectedText = selectedText && selectedText.textContent.trim() === "selected";
                  
                  if (colorName) {
                    results.colors.push({
                      text: colorName,
                      selected: isSelected || hasSelectedText || colorSwatch.classList.contains("selected"),
                      value: imageUrl || colorCode
                    });
                    
                    console.log("Added Guess color: " + colorName);
                  }
                }
              }
            }
          } catch(e) {
            console.error("Error getting Guess colors:", e);
          }
          
          // Extract sizes
          try {
            const sizeContainer = document.querySelector(".variation.single-size, .size-container");
            if (sizeContainer) {
              // First try wrappers
              const sizeWrappers = sizeContainer.querySelectorAll(".attribute__value-wrapper");
              
              if (sizeWrappers && sizeWrappers.length > 0) {
                console.log("Found " + sizeWrappers.length + " size wrappers");
                
                for (let i = 0; i < sizeWrappers.length; i++) {
                  const wrapper = sizeWrappers[i];
                  
                  // Check if wrapper is hidden (out of stock or unavailable)
                  const isHidden = wrapper.classList.contains("d-none");
                  
                  // Get the size button inside the wrapper
                  const sizeButton = wrapper.querySelector(".attribute__btn");
                  if (!sizeButton) continue;
                  
                  // Get size value
                  const sizeValue = sizeButton.getAttribute("data-attr-value") || sizeButton.textContent.trim();
                  if (!sizeValue) continue;
                  
                  // Check if available
                  const isAvailable = !isHidden && sizeButton.classList.contains("selectable") && 
                                     !sizeButton.classList.contains("unselectable");
                  
                  // Check if selected
                  const isSelected = sizeButton.classList.contains("selected") || 
                                    sizeButton.getAttribute("aria-selected") === "true";
                  
                  // Create JSON value with inStock info
                  const valueObj = { 
                    size: sizeValue, 
                    inStock: isAvailable 
                  };
                  
                  results.sizes.push({
                    text: sizeValue,
                    selected: isSelected,
                    value: JSON.stringify(valueObj)
                  });
                  
                  console.log("Added Guess size: " + sizeValue + (isSelected ? " (selected)" : "") + 
                             (isAvailable ? "" : " (out of stock)"));
                }
              } else {
                // Fallback to direct buttons
                const sizeButtons = sizeContainer.querySelectorAll(".attribute__btn");
                
                console.log("Found " + sizeButtons.length + " size buttons");
                
                for (let i = 0; i < sizeButtons.length; i++) {
                  const button = sizeButtons[i];
                  
                  // Get size value
                  const sizeValue = button.getAttribute("data-attr-value") || button.textContent.trim();
                  if (!sizeValue) continue;
                  
                  // Check if available
                  const isAvailable = button.classList.contains("selectable") && 
                                    !button.classList.contains("unselectable");
                  
                  // Check if selected
                  const isSelected = button.classList.contains("selected") || 
                                    button.getAttribute("aria-selected") === "true";
                  
                  // Create JSON value with inStock info
                  const valueObj = { 
                    size: sizeValue, 
                    inStock: isAvailable 
                  };
                  
                  results.sizes.push({
                    text: sizeValue,
                    selected: isSelected,
                    value: JSON.stringify(valueObj)
                  });
                  
                  console.log("Added Guess size: " + sizeValue + (isSelected ? " (selected)" : "") + 
                             (isAvailable ? "" : " (out of stock)"));
                }
              }
            }
          } catch(e) {
            console.error("Error getting Guess sizes:", e);
          }
          
          return results;
        }
              
        // Get Guess-specific variants
        const guessVariants = fetchGuessVariants();
        
        // Log what we found
        console.log("Guess variants retrieved: " + 
                   guessVariants.colors.length + " colors, " + 
                   guessVariants.sizes.length + " sizes");
        
        // If we found any variants, send them to Flutter
        if (guessVariants.colors.length > 0 || guessVariants.sizes.length > 0) {
          // Create message with enhanced variants
          const enhancedMessage = {
            type: "enhanced_variants",
            variants: guessVariants
          };
          
          // Send to Flutter
          FlutterChannel.postMessage(JSON.stringify(enhancedMessage));
        }
      } catch(e) {
        console.error("Error getting enhanced Guess variants:", e);
      }
    `;
  }
};

// Mango Extractor - For extracting Mango product information
const MangoExtractor = {
  // Check if current site is Mango
  isMango: function() {
    const url = window.location.href.toLowerCase();
    return url.includes("mango.com");
  },
  
  // Extract product information from Mango pages
  extract: function() {
    try {
      Logger.info("Extracting product data for Mango");
      
      // Basic product information
      const result = BaseExtractor.createResultObject();
      result.brand = "Mango";
      result.extractionMethod = "mango-specific";
      
      // Extract title
      const titleSelectors = [
        '.ProductDetail_title___WrC_',
        'h1.texts_titleL__HgQ5x',
        '.product-name h1',
        '.product-title h1'
      ];
      
      const titleElement = DOMUtils.querySelector(titleSelectors);
      if (titleElement) {
        result.title = DOMUtils.getTextContent(titleElement);
        Logger.debug(`Found Mango title: ${result.title}`);
      }
      
      // Extract price
      const priceSelectors = [
        '.SinglePrice_center__mfcM3.texts_bodyM__lR_K7',
        '.Price_wrapper__qlieq span[itemprop="price"]',
        '.price__current',
        '.product-price'
      ];
      
      const priceElement = DOMUtils.querySelector(priceSelectors);
      if (priceElement) {
        const priceText = DOMUtils.getTextContent(priceElement);
        result.price = FormatUtils.formatPrice(priceText);
        result.currency = FormatUtils.detectCurrency(priceText) || "TRY"; // Default to TRY if not detected
        Logger.debug(`Found Mango price: ${result.price} ${result.currency}`);
      }
      
      // Extract original price (for sales)
      const originalPriceSelectors = [
        '.price__amount--crossed',
        '.was-price',
        '.original-price',
        '.old-price'
      ];
      
      const originalPriceElement = DOMUtils.querySelector(originalPriceSelectors);
      if (originalPriceElement) {
        const originalPriceText = DOMUtils.getTextContent(originalPriceElement);
        result.originalPrice = FormatUtils.formatPrice(originalPriceText);
        Logger.debug(`Found Mango original price: ${result.originalPrice}`);
      }
      
      // Extract product image
      const imageSelectors = [
        'img.SlideshowWrapper_image__J48xz',
        '.product-images img',
        '.product-photo img',
        '.image-gallery img'
      ];
      
      const imageElement = DOMUtils.querySelector(imageSelectors);
      if (imageElement) {
        // Mango uses srcset for responsive images, so we need to get the largest image URL
        const srcset = imageElement.getAttribute('srcset');
        if (srcset) {
          // Find the largest image from srcset
          const srcsetParts = srcset.split(',');
          if (srcsetParts.length > 0) {
            // Get the last (usually largest) image URL
            const lastPart = srcsetParts[srcsetParts.length - 1].trim();
            const imageUrl = lastPart.split(' ')[0]; // Get URL part
            result.imageUrl = imageUrl;
            Logger.debug(`Found Mango image URL (from srcset): ${result.imageUrl}`);
          }
        } else {
          // If no srcset, use src attribute
          result.imageUrl = imageElement.getAttribute('src');
          Logger.debug(`Found Mango image URL (from src): ${result.imageUrl}`);
        }
      }
      
      // Extract product description
      const descriptionSelectors = [
        '.description',
        '.product-description',
        '.description-content'
      ];
      
      const descriptionElement = DOMUtils.querySelector(descriptionSelectors);
      if (descriptionElement) {
        result.description = DOMUtils.getTextContent(descriptionElement);
        Logger.debug(`Found Mango description: ${result.description}`);
      }
      
      // Extract colors
      try {
        Logger.info("Extracting Mango-specific colors");
        const colorVariants = [];
        
        // Main color selectors based on provided HTML
        const colorSelectorContainer = document.querySelector(".ColorsSelector_colorsSelector__roWxg");
        
        if (colorSelectorContainer) {
          // Get the current selected color name from the label
          const colorLabel = colorSelectorContainer.querySelector(".ColorsSelector_label__52wJk");
          let selectedColorName = '';
          if (colorLabel) {
            selectedColorName = DOMUtils.getTextContent(colorLabel);
            Logger.debug(`Found current selected color: ${selectedColorName}`);
          }
          
          // Get all color items
          const colorItems = document.querySelectorAll(".ColorList_color__n635i");
          Logger.debug(`Found ${colorItems.length} Mango color options`);
          
          if (colorItems && colorItems.length > 0) {
            for (const colorItem of colorItems) {
              // Check if this color is selected
              const isSelected = !!colorItem.querySelector(".ColorSelectorPicker_selected__n16Ry");
              
              // Get the color image
              const colorImg = colorItem.querySelector("img");
              let colorValue = '';
              let colorName = '';
              
              if (colorImg) {
                // Get color name from alt text that follows pattern "Selected color NAME" or just from img alt
                const altText = colorImg.getAttribute('alt') || '';
                if (altText.includes('color')) {
                  colorName = altText.split('color')[1].trim();
                }
                
                // Get image URL for the color
                colorValue = colorImg.getAttribute('src') || colorImg.getAttribute('srcset');
              }
              
              // If we couldn't get color name from alt text, use the selected color label
              if (!colorName && isSelected && selectedColorName) {
                colorName = selectedColorName;
              }
              
              // Fallback if we still don't have a color name
              if (!colorName) {
                colorName = 'Color Option';
              }
              
              // Add the color to our variants
              colorVariants.push({
                text: colorName,
                selected: isSelected,
                value: colorValue || colorName
              });
              
              Logger.debug(`Added Mango color: ${colorName}, Selected: ${isSelected}`);
            }
          }
          
          // If we found colors, add them to the result
          if (colorVariants.length > 0) {
            result.variants.colors = colorVariants;
          }
        } else {
          // Try alternative color selectors if the main one isn't found
          Logger.debug("Using alternative color selectors for Mango");
          
          // Alternative method for extracting colors - try other common selectors
          const colorButtons = document.querySelectorAll('button[aria-label*="color"], div[role="radiogroup"] button');
          if (colorButtons && colorButtons.length > 0) {
            for (const button of colorButtons) {
              const colorName = button.getAttribute('aria-label') || DOMUtils.getTextContent(button);
              const isSelected = button.getAttribute('aria-pressed') === 'true' || 
                                button.hasAttribute('aria-current') ||
                                button.classList.contains('selected');
              
              // Try to get the color image or swatch
              let colorValue = '';
              const colorImg = button.querySelector('img');
              if (colorImg) {
                colorValue = colorImg.getAttribute('src');
              } else {
                const colorStyle = DOMUtils.getStyle(button, 'background-color');
                if (colorStyle && colorStyle !== 'transparent') {
                  colorValue = colorStyle;
                }
              }
              
              if (colorName) {
                colorVariants.push({
                  text: colorName,
                  selected: isSelected,
                  value: colorValue || colorName
                });
                
                Logger.debug(`Added Mango color (alternative method): ${colorName}, Selected: ${isSelected}`);
              }
            }
            
            if (colorVariants.length > 0) {
              result.variants.colors = colorVariants;
            }
          }
        }
      } catch (e) {
        Logger.error("Error extracting Mango colors:", e);
      }
      
      // Extract sizes
      try {
        Logger.info("Extracting Mango-specific sizes");
        const sizeVariants = [];
        
        // First check if sizes are already visible
        const sizeSelectors = [
          ".SizesList_sizesList__SFVLW",
          ".SizeSelector_sizes__bN_5W",
          ".size-selector"
        ];
        
        // Check if we have sizes directly available
        let sizeContainer = DOMUtils.querySelector(sizeSelectors);
        let foundSizes = false;
        
        // If sizes are not visible, try to click the Ekle button to show them
        if (!sizeContainer) {
          Logger.debug("Sizes not immediately visible, looking for Ekle button");
          
          // Try to find the "Ekle" (Add) button - look for various potential selectors
          const ekleButtonSelectors = [
            "button:contains('Ekle')", // Literal text match
            ".add-to-cart", 
            "[data-testid='add-to-cart']",
            "button.add-button",
            ".PrimaryActions_addToBag__59Qzv" // Added for Mango's specific button class
          ];
          
          // Find the button
          const ekleButton = DOMUtils.querySelector(ekleButtonSelectors);
          
          if (ekleButton) {
            Logger.debug("Found Ekle button, clicking to reveal sizes");
            
            try {
              // Save original onclick to restore later if needed
              const originalOnClick = ekleButton.onclick;
              
              // Disable any click handlers temporarily to avoid actual adding to cart
              ekleButton.onclick = function(e) {
                e.preventDefault();
                e.stopPropagation();
                return false;
              };
              
              // Click the button to reveal sizes
              ekleButton.click();
              
              // Wait a tiny bit for sizes to appear in DOM
              setTimeout(function() {
                try {
                  // Now try to find the sizes again
                  sizeContainer = DOMUtils.querySelector(sizeSelectors);
                  
                  if (sizeContainer) {
                    Logger.debug("Sizes revealed after clicking Ekle button");
                    extractSizesFromContainer(sizeContainer);
                    foundSizes = true;
                  }
                  
                  // Restore original click handler
                  if (originalOnClick) {
                    ekleButton.onclick = originalOnClick;
                  }
                } catch (innerError) {
                  Logger.error("Error processing sizes after clicking Ekle:", innerError);
                }
              }, 100);
              
              // Also try for any modal that appears with sizes
              setTimeout(function() {
                try {
                  // Check for sizes in a modal
                  const modalSizeSelectors = [
                    ".modal .SizesList_sizesList__SFVLW",
                    ".size-selector-modal .sizes",
                    ".size-modal",
                    ".SheetContent_content__sJjkI" // Added for Mango's sheet content class
                  ];
                  
                  const modalSizes = DOMUtils.querySelector(modalSizeSelectors);
                  if (modalSizes && !foundSizes) {
                    Logger.debug("Found sizes in modal after clicking Ekle");
                    extractSizesFromContainer(modalSizes);
                    foundSizes = true;
                  }
                } catch (modalError) {
                  Logger.error("Error processing modal sizes:", modalError);
                }
              }, 200);
            } catch (clickError) {
              Logger.error("Error clicking Ekle button:", clickError);
            }
          } else {
            Logger.debug("Could not find Ekle button");
          }
        } else {
          // If sizes are directly visible, extract them
          Logger.debug("Sizes are directly visible in the DOM");
          extractSizesFromContainer(sizeContainer);
          foundSizes = true;
        }
        
        // Helper function to extract sizes from a container
        function extractSizesFromContainer(container) {
          if (!container) return;
          
          // For tracking already processed sizes to avoid duplicates
          const processedSizes = new Map();
          
          // Get all size items/buttons
          const sizeItems = container.querySelectorAll("li button, li, button.SizeItem_sizeItem__v0Bm2");
          Logger.debug(`Found ${sizeItems.length} size items`);
          
          for (const sizeItem of sizeItems) {
            // Skip non-relevant items
            if (!sizeItem || DOMUtils.getTextContent(sizeItem).trim() === '') {
              continue;
            }
            
            // Extract size text - could be in a child span
            let sizeText = '';
            const sizeSpan = sizeItem.querySelector(".texts_bodyMRegular__j0yfK, .size-text");
            
            if (sizeSpan) {
              sizeText = DOMUtils.getTextContent(sizeSpan);
            } else {
              sizeText = DOMUtils.getTextContent(sizeItem);
            }
            
            // Skip if size text is empty or not a valid size
            if (!sizeText || sizeText.trim() === '' || 
                sizeText.toLowerCase().includes('select') ||
                sizeText.toLowerCase().includes('seçin')) {
              continue;
            }
            
            // Clean up size text - remove any non-size text that might be in the same element
            sizeText = sizeText.trim();
            
            // Check if this size is selected
            const isSelected = sizeItem.classList.contains('selected') || 
                              sizeItem.classList.contains('SizeItem_selected__tH_5C') ||
                              sizeItem.getAttribute('aria-pressed') === 'true' ||
                              sizeItem.getAttribute('aria-selected') === 'true' ||
                              sizeItem.classList.contains('active');
            
            // Check if this size is available or out of stock
            const isDisabled = sizeItem.hasAttribute('disabled') || 
                              sizeItem.classList.contains('disabled') ||
                              sizeItem.classList.contains('unavailable') ||
                              !sizeItem.classList.contains('SizeItem_selectable__ETiIg'); // Not selectable = not in stock
            
            // For Mango specifically, we need a different approach for checking availability
            const isMango = window.location.href.toLowerCase().includes("mango.com");
            let isInStock = !isDisabled;
            
            // Check for delayed delivery information (specific to Mango)
            let hasDelayedDelivery = false;
            let deliveryInfo = null;
            
            // Special handling for Mango sizes
            if (isMango) {
              // Check for marker classes that indicate unavailability
              const isUnavailable = sizeItem.innerHTML.includes('SizeItemContent_notAvailable__') || 
                                   sizeItem.innerHTML.includes('SizeItemContent_notifyMe__');
              
              // Look for delayed delivery labels within the size item
              const delayedLabel = sizeItem.querySelector(".SizeDelayedLabel_sizeDelayedLabel__lLZqd");
              if (delayedLabel) {
                hasDelayedDelivery = true;
                deliveryInfo = DOMUtils.getTextContent(delayedLabel).trim();
                Logger.debug(`Found delayed delivery info: ${deliveryInfo}`);
              }
              
              // Log comprehensive details about the element structure
              Logger.debug(`Mango size ${sizeText} HTML structure: ${sizeItem.innerHTML.substring(0, 100)}...`);
              Logger.debug(`Mango size ${sizeText}: isUnavailable = ${isUnavailable}, hasDelayedDelivery = ${hasDelayedDelivery}`);
              
              // A size is in stock if it doesn't have unavailability markers
              isInStock = !isUnavailable;
              
              // Log all classes on this element for debugging
              const allClasses = Array.from(sizeItem.classList).join(', ');
              Logger.debug(`Mango size ${sizeText} classes: ${allClasses}, availability: ${isInStock}`);
            }
            
            // Create a value object with stock information
            const valueObj = {
              size: sizeText,
              inStock: isInStock,
              delayedDelivery: hasDelayedDelivery,
              deliveryInfo: deliveryInfo
            };
            const valueJson = JSON.stringify(valueObj);
            
            // Check if we've already processed this size
            if (processedSizes.has(sizeText)) {
              // Only update if this entry has more information
              const existingValue = processedSizes.get(sizeText);
              
              // If the current entry is selected and the existing one isn't, replace it
              if (isSelected && !existingValue.selected) {
                processedSizes.set(sizeText, {
                  text: sizeText,
                  selected: isSelected,
                  value: valueJson
                });
                Logger.debug(`Updated Mango size: ${sizeText}, Selected: ${isSelected}, InStock: ${isInStock}, Delayed: ${hasDelayedDelivery}`);
              }
              
              // If the current entry has delivery info and the existing one doesn't, replace it
              else if (hasDelayedDelivery && !existingValue.value.includes('delayedDelivery')) {
                processedSizes.set(sizeText, {
                  text: sizeText,
                  selected: isSelected || existingValue.selected, // Preserve selection state
                  value: valueJson
                });
                Logger.debug(`Updated Mango size with delivery info: ${sizeText}, InStock: ${isInStock}`);
              }
            } else {
              // First time seeing this size, add it to the map
              processedSizes.set(sizeText, {
                text: sizeText,
                selected: isSelected,
                value: valueJson
              });
              
              Logger.debug(`Added Mango size: ${sizeText}, Selected: ${isSelected}, InStock: ${isInStock}, Delayed: ${hasDelayedDelivery}`);
            }
          }
          
          // Convert the map values to an array and add to sizeVariants
          for (const sizeOption of processedSizes.values()) {
            sizeVariants.push(sizeOption);
          }
          
          Logger.debug(`After deduplication: ${sizeVariants.length} unique Mango sizes`);
        }
        
        // If we found sizes through any method, add them to the result
        if (sizeVariants.length > 0) {
          result.variants.sizes = sizeVariants;
          Logger.info(`Extracted ${sizeVariants.length} sizes from Mango product`);
        } else {
          // Fallback - try to find any hidden size data in the page
          Logger.debug("No sizes found through DOM, checking for hidden size data");
          
          // Check for size data in script tags
          const scriptTags = document.querySelectorAll('script:not([src])');
          for (const script of scriptTags) {
            const scriptContent = script.textContent || '';
            
            if (scriptContent.includes('"sizes"') || scriptContent.includes('"size"')) {
              try {
                // Look for JSON objects in the script text
                const jsonMatches = scriptContent.match(/\{[\s\S]*?"size[s]?"[\s\S]*?\}/g);
                
                if (jsonMatches && jsonMatches.length > 0) {
                  for (const jsonMatch of jsonMatches) {
                    try {
                      const sizeData = JSON.parse(jsonMatch);
                      
                      // Check if this has size information
                      if (sizeData.sizes || sizeData.size) {
                        const sizes = sizeData.sizes || sizeData.size;
                        
                        if (Array.isArray(sizes)) {
                          // Process size array
                          for (const size of sizes) {
                            if (typeof size === 'string') {
                              sizeVariants.push({
                                text: size,
                                selected: false,
                                value: JSON.stringify({ size: size, inStock: true })
                              });
                            } else if (typeof size === 'object') {
                              const sizeText = size.name || size.value || size.text || '';
                              const isInStock = size.inStock !== false; // Assume in stock unless explicitly false
                              
                              if (sizeText) {
                                sizeVariants.push({
                                  text: sizeText,
                                  selected: !!size.selected,
                                  value: JSON.stringify({ size: sizeText, inStock: isInStock })
                                });
                              }
                            }
                          }
                        }
                      }
                    } catch (jsonError) {
                      // Skip invalid JSON
                    }
                  }
                }
              } catch (parseError) {
                // Skip errors in script parsing
              }
            }
          }
          
          // If we found sizes in scripts, add them
          if (sizeVariants.length > 0) {
            result.variants.sizes = sizeVariants;
            Logger.info(`Extracted ${sizeVariants.length} sizes from script tags`);
          } else {
            Logger.warn("Could not extract size information from Mango product");
          }
        }
      } catch (e) {
        Logger.error("Error extracting Mango sizes:", e);
      }
      
      // Check if we have the minimum needed information for success
      result.success = !!(result.title && result.price);
      Logger.info(`Mango extraction success: ${result.success}`);
      
      return result;
    } catch (e) {
      Logger.error("Error extracting Mango product data", e);
      return {
        isProductPage: true,
        success: false,
        brand: "Mango",
        url: window.location.href,
        extractionMethod: "mango-specific-failed",
        error: e.message
      };
    }
  }
};

// Bershka size extraction
function extractBershkaSizes() {
  const results = { sizes: [] };
  
  try {
    Logger.info("🔍 Attempting to extract Bershka sizes");
    
    // Log the current URL for debugging
    Logger.debug(`Current URL: ${window.location.href}`);
    
    // Log entire page structure for button finding
    Logger.debug("Looking for size button in DOM");
    
    // Dump all buttons on the page with their text content for debugging
    const allButtons = document.querySelectorAll('button');
    Logger.debug(`Found ${allButtons.length} total buttons on page`);
    for (let i = 0; i < Math.min(allButtons.length, 10); i++) {
      const btn = allButtons[i];
      Logger.debug(`Button ${i}: class="${btn.className}" text="${btn.textContent.trim()}" data-attrs="${btn.dataset ? Object.keys(btn.dataset).join(',') : 'none'}"`);
    }
    
    // First try to identify all potential containers for size data
    Logger.debug("Looking for size containers in the DOM");
    const possibleContainers = [
      document.querySelector('.sizes-list-dialog .ui--size-list'),
      document.querySelector('[data-qa-anchor="productDetailSize"] .ui--size-list'),
      document.querySelector('.ui--size-list'),
      document.querySelector('[data-qa-anchor="wishlistSizes"]'),
      document.querySelector('.single-length-list__content ul')
    ];
    
    const sizesContainer = possibleContainers.find(container => container !== null);
    
    // Check if size container is already visible
    if (sizesContainer) {
      Logger.info("✅ Found sizes container already visible");
    } else {
      // If container not found, look specifically for the size button using various selectors
      Logger.info("No size container found, looking for size button to click");
      
      // Try more specific selectors for Bershka's layout
      const sizeButtonSelectors = [
        '.product-page-actions button.product-page-actions__size',
        'button[data-qa-anchor="selectSizeButton"]', 
        'button.product-page-actions__size',
        'button.size-selector',
        'button.size-selector-button',
        '.product-page-actions__size',
        'button[type="button"].product-detail-size-selector', 
        'button.product-detail-size-selector',
        // Try to find by text content
        'button:not([disabled]):not([hidden]):not([aria-hidden="true"]).product-page-actions__size',
        'button:not([disabled]):not([hidden]):not([aria-hidden="true"]):nth-child(1)',
        // Try by content text
        'button.product-page-actions__info-title',
        // Last resort - find any button that looks like a size selector
        'button:not([disabled]):not([hidden]):not([aria-hidden="true"])',
      ];
      
      // Try to find the button
      let sizeButton = null;
      for (const selector of sizeButtonSelectors) {
        const buttons = document.querySelectorAll(selector);
        if (buttons && buttons.length > 0) {
          // Look for a button with size-related text
          for (const btn of buttons) {
            const text = btn.textContent.trim().toLowerCase();
            if (text.includes('size') || text.includes('select size') || text.includes('choose size') || 
                text.includes('select a size') || text.includes('boyut') || text.includes('beden')) {
              sizeButton = btn;
              Logger.debug(`Found size button with text: "${text}"`);
              break;
            }
          }
          
          // If we didn't find by text but found buttons, take the first one
          if (!sizeButton && buttons.length > 0) {
            sizeButton = buttons[0];
            Logger.debug(`Found potential size button with selector: ${selector}`);
          }
          
          if (sizeButton) break;
        }
      }
      
      // If still not found, try to find by iterating buttons with size-related text
      if (!sizeButton) {
        Logger.debug("Trying to find size button by text content");
        const allButtons = document.querySelectorAll('button:not([disabled]):not([hidden]):not([aria-hidden="true"])');
        for (const btn of allButtons) {
          const text = btn.textContent.trim().toLowerCase();
          if (text.includes('size') || text.includes('select size') || text.includes('choose size') || 
              text.includes('select a size') || text.includes('boyut') || text.includes('beden')) {
            sizeButton = btn;
            Logger.debug(`Found size button by text: "${text}"`);
            break;
          }
        }
      }
      
      if (sizeButton) {
        Logger.info("📱 Found size button, clicking to show options");
        // Add extra logging about the button
        Logger.debug(`Size button text: ${sizeButton.textContent.trim()}`);
        Logger.debug(`Size button class: ${sizeButton.className}`);
        Logger.debug(`Size button HTML: ${sizeButton.outerHTML}`);
        
        // Click the button
        sizeButton.click();
        
        // Listen for DOM changes after clicking - this might help detect when the dialog appears
        const observer = new MutationObserver((mutations) => {
          Logger.debug("DOM changed after size button click, checking for size dialog");
          
          // Check if size dialog appeared
          const dialog = document.querySelector('.sizes-list-dialog, [data-qa-anchor="productDetailSize"]');
          if (dialog) {
            Logger.debug("Size dialog appeared after button click");
            observer.disconnect();
            
            // Try to extract sizes now that dialog is visible
            setTimeout(() => {
              const results = extractBershkaSizes();
              Logger.debug(`Size extraction after dialog appeared: ${results.sizes.length} sizes`);
            }, 300);
          }
        });
        
        // Start observing the document with the configured mutation observer
        observer.observe(document.body, { childList: true, subtree: true });
        
        // Wait longer for the dialog to appear (1200ms instead of 800ms)
        Logger.info("Waiting for size dialog to appear...");
        setTimeout(() => {
          observer.disconnect();
          const results = extractBershkaSizes();
          Logger.debug(`Size extraction after click returned ${results.sizes.length} sizes`);
        }, 1200);
        
        return results;
      } else {
        Logger.warn("❌ No size button found to click");
        
        // Last resort - dump HTML structure of product page areas for debugging
        const productActions = document.querySelector('.product-page-actions, .product-detail-actions');
        if (productActions) {
          Logger.debug(`Product actions HTML: ${productActions.outerHTML.substring(0, 1000)}...`);
        }
      }
    }
    
    // Once the dialog is open, extract sizes
    if (sizesContainer) {
      Logger.info("✅ Found sizes container");
      Logger.debug(`Container class: ${sizesContainer.className}`);
      Logger.debug(`Container HTML: ${sizesContainer.outerHTML.substring(0, 500)}...`);
      
      // Try multiple selector patterns for size items
      const sizeItemsSelectors = [
        'li.list-item button.ui--list-item',
        'button[data-qa-anchor="sizeListItem"]',
        'li button',
        'button.ui--list-item',
        '.name', // Direct size name elements
      ];
      
      let sizeItems = [];
      for (const selector of sizeItemsSelectors) {
        const items = sizesContainer.querySelectorAll(selector);
        if (items && items.length > 0) {
          sizeItems = items;
          Logger.debug(`Found ${items.length} size items using selector: ${selector}`);
          break;
        }
      }
      
      Logger.debug(`Found ${sizeItems.length} size items`);
      
      // Capture raw HTML for debugging if no items found
      if (sizeItems.length === 0) {
        Logger.debug(`Container HTML: ${sizesContainer.outerHTML.substring(0, 1000)}...`);
        
        // Try direct text extraction if no items found with selectors
        const sizeText = sizesContainer.textContent.trim();
        Logger.debug(`Container text content: ${sizeText}`);
        
        // Try to extract size names from text content
        const sizeMatches = sizeText.match(/XS|S|M|L|XL|XXL|\d+\.\d+|\d+/g);
        if (sizeMatches && sizeMatches.length > 0) {
          Logger.debug(`Found ${sizeMatches.length} size matches in text: ${sizeMatches.join(', ')}`);
          
          // Create size items from text matches
          for (const size of sizeMatches) {
            results.sizes.push({
              text: size,
              selected: false,
              value: JSON.stringify({ 
                size: size, 
                inStock: true, 
                limitedStock: false 
              }),
            });
          }
          
          // Log the results
          Logger.info(`✅ Extracted ${results.sizes.length} Bershka sizes from text matching`);
        }
      } else {
        for (let i = 0; i < sizeItems.length; i++) {
          const sizeItem = sizeItems[i];
          
          // Log the raw HTML of the first item for debugging
          if (i === 0) {
            Logger.debug(`First size item HTML: ${sizeItem.outerHTML}`);
          }
          
          // Check if selected (has aria-checked="true")
          const isSelected = sizeItem.getAttribute('aria-checked') === 'true' || 
                            sizeItem.classList.contains('is-active');
          
          // Check if in stock (doesn't have "sold out" text and no disabled class)
          const hasLimitedStock = sizeItem.classList.contains('is-last-units');
          
          // Try multiple selectors for the extra-info element
          const extraInfoElement = sizeItem.querySelector('.extra-info') || 
                                  sizeItem.querySelector('.list-item__action-buttons') || 
                                  sizeItem.querySelector('.availability');
          
          const extraInfoText = extraInfoElement ? extraInfoElement.textContent.trim() : '';
          
          // Check if out of stock or disabled
          const isOutOfStock = sizeItem.classList.contains('is-disabled') || 
                            extraInfoText.includes('Sold out') || 
                            extraInfoText.includes('out of stock');
          
          const isInStock = !isOutOfStock;
          
          // Extract size name from the button text
          let sizeName = '';
          const nameElement = sizeItem.querySelector('.name') || 
                            sizeItem.querySelector('.text span.name');
          
          if (nameElement) {
            sizeName = nameElement.textContent.trim();
          } else {
            // Fallback: try to get text directly from the button
            const buttonText = sizeItem.textContent.trim();
            if (buttonText) {
              // Try to extract size from button text, removing any "sold out" or similar phrases
              sizeName = buttonText.replace(/sold out|out of stock|only a few left/i, '').trim();
            }
          }
          
          if (sizeName) {
            Logger.debug(`Adding size: ${sizeName}, Selected: ${isSelected}, In stock: ${isInStock}, Limited: ${hasLimitedStock}`);
            results.sizes.push({
              text: sizeName,
              selected: isSelected,
              value: JSON.stringify({ 
                size: sizeName, 
                inStock: isInStock, 
                limitedStock: hasLimitedStock 
              }),
            });
          }
        }
        
        // Log the results
        Logger.info(`✅ Extracted ${results.sizes.length} Bershka sizes`);
        
        // Log the actual size data for debugging
        if (results.sizes.length > 0) {
          Logger.debug(`Size data sample: ${JSON.stringify(results.sizes[0])}`);
        }
      }
    } else {
      Logger.warn("❌ Couldn't find Bershka sizes container");
      
      // Last resort - try to directly find size elements scattered in the DOM
      Logger.debug("Trying direct DOM search for size elements");
      
      // Check for common size patterns anywhere in the document
      const sizePatterns = ['XS', 'S', 'M', 'L', 'XL', 'XXL'];
      const sizeElements = [];
      
      // Loop through size patterns and try to find them in the document
      for (const pattern of sizePatterns) {
        const elements = document.querySelectorAll(`*:not(script):not(style):contains("${pattern}")`);
        if (elements && elements.length > 0) {
          for (const element of elements) {
            // Only consider elements that are likely to be size indicators
            if (element.tagName.toLowerCase() === 'button' || 
                element.tagName.toLowerCase() === 'span' || 
                element.tagName.toLowerCase() === 'div' || 
                element.tagName.toLowerCase() === 'li') {
              const text = element.textContent.trim();
              // Only add if the text is exactly the size pattern (or very close)
              if (text === pattern || text.startsWith(pattern + ' ') || text.endsWith(' ' + pattern)) {
                sizeElements.push({ element, size: pattern });
              }
            }
          }
        }
      }
      
      if (sizeElements.length > 0) {
        Logger.debug(`Found ${sizeElements.length} potential size elements directly in DOM`);
        
        // Add sizes from found elements
        const addedSizes = new Set();
        for (const {element, size} of sizeElements) {
          if (!addedSizes.has(size)) {
            addedSizes.add(size);
            results.sizes.push({
              text: size,
              selected: false,
              value: JSON.stringify({ 
                size: size, 
                inStock: true,
                limitedStock: false 
              }),
            });
          }
        }
        
        Logger.info(`✅ Extracted ${results.sizes.length} Bershka sizes from direct DOM search`);
      }
      
      // If still no sizes, create default sizes
      if (results.sizes.length === 0) {
        // Create default sizes as a last resort
        const defaultSizes = ['XS', 'S', 'M', 'L', 'XL'];
        for (const size of defaultSizes) {
          results.sizes.push({
            text: size,
            selected: size === 'M', // Select medium as default
            value: JSON.stringify({ 
              size: size, 
              inStock: true,
              limitedStock: false 
            }),
          });
        }
        
        Logger.info(`✅ Created ${results.sizes.length} default Bershka sizes`);
      }
    }
  } catch(e) {
    Logger.error("❌ Error getting Bershka sizes:", e);
  }
  
  return results;
}

// Bershka Extractor - For extracting Bershka product information
const BershkaExtractor = {
  // Check if current site is Bershka
  isBershka: function() {
    const url = window.location.href.toLowerCase();
    return url.includes("bershka.com");
  },
  
  // Check if this is a product page (more specific than just domain check)
  isProductPage: function() {
    const url = window.location.href.toLowerCase();
    // Product URLs contain c0p followed by numbers and .html
    const urlMatch = /bershka\.com\/.*c0p\d+\.html/.test(url);
    
    // Also check DOM for product page indicators
    const domMatch = document.querySelector('[data-qa-anchor="productDetailSize"], [data-qa-anchor="productDetailColors"], [data-qa-anchor="productName"]') !== null;
    
    return urlMatch || domMatch;
  },
  
  // Extract product information from Bershka pages
  extract: function() {
    try {
      Logger.info("Extracting product data for Bershka");
      
      // First verify this is a product page
      if (!this.isProductPage()) {
        Logger.info("Not a Bershka product page, skipping extraction");
        return {
          isProductPage: false,
          success: false,
          url: window.location.href,
          message: "Not a Bershka product page"
        };
      }
      
      // Basic product information
      const result = BaseExtractor.createResultObject();
      result.brand = "Bershka";
      result.extractionMethod = "bershka-specific";
      
      // Extract title
      const titleSelectors = [
        'h1.product-info__name',
        '.product-title h1',
        'h1.product-name',
        '[data-qa-anchor="productName"]'
      ];
      
      const titleElement = DOMUtils.querySelector(titleSelectors);
      if (titleElement) {
        result.title = DOMUtils.getTextContent(titleElement);
        Logger.debug(`Found Bershka title: ${result.title}`);
      }
      
      // Extract price
      const priceSelectors = [
        '.product-info__price span[data-qa-anchor="productPrice"]',
        'span[data-qa-anchor="productPrice"]',
        '.product-price .current',
        '[data-qa-anchor="currentPrice"]'
      ];
      
      const priceElement = DOMUtils.querySelector(priceSelectors);
      if (priceElement) {
        const priceText = DOMUtils.getTextContent(priceElement);
        result.price = FormatUtils.formatPrice(priceText);
        result.currency = FormatUtils.detectCurrency(priceText) || "TRY"; // Default to TRY if not detected
        Logger.debug(`Found Bershka price: ${result.price} ${result.currency}`);
      }
      
      // Extract original price (for sales)
      const originalPriceSelectors = [
        'span[data-qa-anchor="productPreviousPrice"]',
        '.product-info__price .previous',
        '.product-price .previous',
        '[data-qa-anchor="oldPrice"]'
      ];
      
      const originalPriceElement = DOMUtils.querySelector(originalPriceSelectors);
      if (originalPriceElement) {
        const originalPriceText = DOMUtils.getTextContent(originalPriceElement);
        result.originalPrice = FormatUtils.formatPrice(originalPriceText);
        Logger.debug(`Found Bershka original price: ${result.originalPrice}`);
      }
      
      // Extract product image
      const imageSelectors = [
        '.product-gallery__image img',
        '.media-viewer img.main-image',
        '.image-container img',
        '[data-qa-anchor="imageProductPage"] img',
        '.product-images img'
      ];
      
      const imageElement = DOMUtils.querySelector(imageSelectors);
      if (imageElement) {
        // Get the source or data attribute that contains the image URL
        result.imageUrl = imageElement.getAttribute('src') || 
                         imageElement.getAttribute('data-src') ||
                         imageElement.getAttribute('srcset') ||
                         imageElement.getAttribute('data-srcset');
        
        Logger.debug(`Found Bershka image URL: ${result.imageUrl}`);
      }
      
      // Extract product description
      const descriptionSelectors = [
        '.product-info__description',
        '.description-container',
        '.product-description',
        '[data-qa-anchor="productDetailDescription"]'
      ];
      
      const descriptionElement = DOMUtils.querySelector(descriptionSelectors);
      if (descriptionElement) {
        result.description = DOMUtils.getTextContent(descriptionElement);
        Logger.debug(`Found Bershka description: ${result.description}`);
      }
      
      // Extract colors
      try {
        Logger.info("Extracting Bershka-specific colors");
        const colorVariants = [];
        
        // Color selector container
        const colorSelectorContainer = document.querySelector('[data-qa-anchor="productDetailColors"]');
        
        if (colorSelectorContainer) {
          // Get all color swatches
          const colorItems = colorSelectorContainer.querySelectorAll('button[data-qa-anchor="colorSwatch"]');
          Logger.debug(`Found ${colorItems.length} Bershka color options`);
          
          if (colorItems && colorItems.length > 0) {
            for (const colorItem of colorItems) {
              // Check if this color is selected
              const isSelected = colorItem.getAttribute('aria-pressed') === 'true' || 
                               colorItem.classList.contains('is-active');
              
              // Get the color name and image
              const colorImg = colorItem.querySelector('img');
              let colorValue = '';
              let colorName = '';
              
              // Try to get the color name from aria-label or title
              colorName = colorItem.getAttribute('aria-label') || colorItem.getAttribute('title');
              
              // If we have an image, use its alt text or src as a fallback for the name
              if (colorImg) {
                if (!colorName) {
                  colorName = colorImg.getAttribute('alt');
                }
                colorValue = colorImg.getAttribute('src');
              }
              
              // Fallback if we still don't have a color name
              if (!colorName) {
                colorName = 'Color Option';
              }
              
              // Add the color to our variants
              colorVariants.push({
                text: colorName,
                selected: isSelected,
                value: colorValue || colorName
              });
              
              Logger.debug(`Added Bershka color: ${colorName}, Selected: ${isSelected}`);
            }
          }
          
          // If we found colors, add them to the result
          if (colorVariants.length > 0) {
            result.variants = result.variants || {};
            result.variants.colors = colorVariants;
          }
        }
      } catch(e) {
        Logger.error("Error extracting Bershka colors:", e);
      }
      
      // Extract sizes using the specialized function
      try {
        const sizeResults = extractBershkaSizes();
        if (sizeResults && sizeResults.sizes && sizeResults.sizes.length > 0) {
          result.variants = result.variants || {};
          result.variants.sizes = sizeResults.sizes;
        }
      } catch(e) {
        Logger.error("Error extracting Bershka sizes:", e);
      }
      
      // Check if we have enough information to consider this successful
      result.success = !!(result.title && result.price);
      
      return result;
    } catch(e) {
      Logger.error("Error in Bershka extractor:", e);
      return {
        isProductPage: true,
        success: false,
        url: window.location.href,
        error: e.message,
        extractionMethod: "bershka-failed"
      };
    }
  }
};

// Extract sizes for Massimo Dutti products
function extractMassimoDuttiSizes() {
  const results = { sizes: [] };
  
  try {
    Logger.info("🔍 Attempting to extract Massimo Dutti sizes");
    
    // Log the current URL for debugging
    Logger.debug(`Current URL: ${window.location.href}`);
    
    // Find the main size selector container
    const sizeContainer = document.querySelector('product-size-selector-layout, .product-size-selector, .tabs.product-size-selector');
    
    if (!sizeContainer) {
      Logger.warn("❌ No size container found for Massimo Dutti");
      return results;
    }
    
    Logger.debug(`Found Massimo Dutti size container: ${sizeContainer.className}`);
    
    // Find all size buttons
    const sizeButtons = sizeContainer.querySelectorAll('button[role="option"], .product-size-selector__li button');
    
    if (!sizeButtons || sizeButtons.length === 0) {
      Logger.warn("❌ No size buttons found in container");
      return results;
    }
    
    Logger.info(`✅ Found ${sizeButtons.length} size options`);
    
    // Process each size button
    for (const button of sizeButtons) {
      // Extract size text
      const sizeTextElement = button.querySelector('.tab-inner-size');
      if (!sizeTextElement) continue;
      
      const sizeText = sizeTextElement.textContent.trim();
      if (!sizeText) continue;
      
      // Determine if this size is selected
      const isSelected = button.getAttribute('aria-selected') === 'true';
      
      // Determine stock status
      let isInStock = true; // Default to in stock
      let isBackSoon = false;
      
      // Check for unavailable status
      if (button.classList.contains('c-middle-grey')) {
        // This indicates either "Back Soon" or "Sold Out"
        
        // Check for specific icons/labels
        const icon = button.querySelector('.icon-sizes');
        if (icon) {
          const statusText = icon.getAttribute('data-title');
          if (statusText) {
            Logger.debug(`Size ${sizeText} has status: ${statusText}`);
            
            if (statusText.includes('ÇOK YAKINDA') || statusText.toLowerCase().includes('back soon')) {
              isInStock = false;
              isBackSoon = true;
            } else if (statusText.includes('dev.product.soldOut') || statusText.toLowerCase().includes('sold out')) {
              isInStock = false;
              isBackSoon = false;
            }
          }
        }
      }
      
      // Create the value object with stock information
      const valueObj = {
        size: sizeText,
        inStock: isInStock,
        backSoon: isBackSoon
      };
      
      // Add to results
      results.sizes.push({
        text: sizeText,
        selected: isSelected,
        value: JSON.stringify(valueObj)
      });
      
      Logger.debug(`Added Massimo Dutti size: ${sizeText}, Selected: ${isSelected}, InStock: ${isInStock}, BackSoon: ${isBackSoon}`);
    }
    
    Logger.info(`✅ Extracted ${results.sizes.length} sizes from Massimo Dutti product`);
  } catch (error) {
    Logger.error(`Error extracting Massimo Dutti sizes: ${error}`);
  }
  
  return results;
}

// Massimo Dutti size extraction
function extractMassimoDuttiSizes() {
  // ... existing code ...
}

// Pandora Extractor - For extracting Pandora product information
const PandoraExtractor = {
  // Check if current site is Pandora
  isPandora: function() {
    const url = window.location.href.toLowerCase();
    return url.includes("pandora.net");
  },
  
  // Extract product information from Pandora pages
  extract: function() {
    try {
      Logger.info("Extracting product data for Pandora");
      
      // Basic product information
      const result = BaseExtractor.createResultObject();
      result.brand = "Pandora";
      result.extractionMethod = "pandora-specific";
      
      // Only initialize variants that exist
      if (!result.variants) {
        result.variants = {};
      }
      
      // Check for color options
      const hasColorOptions = !!document.querySelector('.variation-attribute[data-attr="color-group"]');
      if (hasColorOptions) {
        result.variants.colors = [];
        Logger.debug("Found color options container");
      }
      
      // Check for size options
      const hasSizeOptions = !!document.querySelector('.size-attribute-container, select[name="ring-size"], .pdp-size-section');
      if (hasSizeOptions) {
        result.variants.sizes = [];
        Logger.debug("Found size options container");
      }
      
      Logger.debug("Initialized variants object for Pandora");
      
      // Extract title
      const titleSelectors = [
        '.product-name', 
        '.pdp-title',
        'h1.page-title',
        '.ProductDetailMainInfo h1'
      ];
      
      const titleElement = DOMUtils.querySelector(titleSelectors);
      if (titleElement) {
        result.title = DOMUtils.getTextContent(titleElement);
        Logger.debug(`Found Pandora title: ${result.title}`);
      }
      
      // Extract price
      const priceSelectors = [
        '.product-price .price',
        '.price-container .price',
        '.ProductDetailMainInfo .price',
        '.product-info-main .price',
        '[data-price-type="finalPrice"]',
        '.sales.sales-origin .value'
      ];
      
      const priceElement = DOMUtils.querySelector(priceSelectors);
      if (priceElement) {
        const priceText = DOMUtils.getTextContent(priceElement);
        result.price = FormatUtils.formatPrice(priceText);
        result.currency = FormatUtils.detectCurrency(priceText) || "TRY"; // Default to TRY if not detected
        Logger.debug(`Found Pandora price: ${result.price} ${result.currency}`);
      }
      
      // Extract original price (for sales)
      const originalPriceSelectors = [
        '.old-price .price',
        '.price-container .old-price',
        '[data-price-type="oldPrice"]',
        '.price-was-container'
      ];
      
      const originalPriceElement = DOMUtils.querySelector(originalPriceSelectors);
      if (originalPriceElement) {
        const originalPriceText = DOMUtils.getTextContent(originalPriceElement);
        result.originalPrice = FormatUtils.formatPrice(originalPriceText);
        Logger.debug(`Found Pandora original price: ${result.originalPrice}`);
      }
      
      // Extract product image
      const imageSelectors = [
        '.gallery-placeholder img',
        '.product-image-gallery img',
        '.fotorama__stage__shaft img',
        '.MagicZoom img',
        '.pdp-primary-images img'
      ];
      
      const imageElement = DOMUtils.querySelector(imageSelectors);
      if (imageElement) {
        // Get high-res image URL if available
        const dataFullImage = imageElement.getAttribute('data-full') || 
                             imageElement.getAttribute('data-zoom-image') || 
                             imageElement.getAttribute('data-product-lg-image');
                             
        result.imageUrl = FormatUtils.makeUrlAbsolute(
          dataFullImage || imageElement.getAttribute('src')
        );
        Logger.debug(`Found Pandora image URL: ${result.imageUrl}`);
      }
      
      // Extract product description
      const descriptionSelectors = [
        '.product-description',
        '.description',
        '.value[itemprop="description"]',
        '.product.attribute.overview',
        '.product.attribute.description'
      ];
      
      const descriptionElement = DOMUtils.querySelector(descriptionSelectors);
      if (descriptionElement) {
        result.description = DOMUtils.getTextContent(descriptionElement);
        Logger.debug(`Found Pandora description`);
      }
      
      // Extract product SKU/product code
      const skuSelectors = [
        '.product.attribute.sku .value',
        '.sku .value',
        '[itemprop="sku"]',
        '.product-id-sku'
      ];
      
      const skuElement = DOMUtils.querySelector(skuSelectors);
      if (skuElement) {
        result.sku = DOMUtils.getTextContent(skuElement);
        Logger.debug(`Found Pandora SKU: ${result.sku}`);
      } else {
        // Try to extract SKU from URL
        const skuMatch = window.location.href.match(/\/([A-Z0-9]+)\.html/);
        if (skuMatch && skuMatch[1]) {
          result.sku = skuMatch[1];
          Logger.debug(`Extracted Pandora SKU from URL: ${result.sku}`);
        }
      }
      
      // Extract metal variants - specific to Pandora jewelry
      this.extractPandoraMetalVariants(result);
      
      // Extract size variants - specific to Pandora jewelry
      this.extractPandoraSizeVariants(result);
      
      // Check if we have the minimum needed information for success
      result.success = !!(result.title && result.price);
      
      // Log final number of variants for debugging
      Logger.debug(`Final Pandora variants - colors: ${result.variants.colors.length}, sizes: ${result.variants.sizes.length}`);
      
      return result;
    } catch (e) {
      Logger.error("Error extracting Pandora product data", e);
      return {
        isProductPage: true,
        success: false,
        brand: "Pandora",
        url: window.location.href,
        extractionMethod: "pandora-specific-failed",
        error: e.message
      };
    }
  },
  
  // Extract metal variants for Pandora products
  extractPandoraMetalVariants: function(result) {
    try {
      Logger.info("Extracting Pandora metal variants");
      
      // First check if this product has color options at all
      const hasColorOptions = !!document.querySelector('.variation-attribute[data-attr="color-group"]');
      
      if (!hasColorOptions) {
        Logger.debug("No color options found for this Pandora product - skipping color extraction");
        // Don't create an empty colors array if no colors exist
        delete result.variants.colors;
        return;
      }
      
      // First try to find the color-group-container based on the HTML structure provided by the user
      const colorGroupContainer = document.querySelector('#color-group-selector-198421C01, #color-group-selector-198421C03, .color-group-container, ul[id^="color-group-selector"]');
      
      if (colorGroupContainer) {
        Logger.debug("Found color group container using ID or class selector");
        
        // Find all color attributes
        const colorAttributes = colorGroupContainer.querySelectorAll('.color-attribute');
        if (colorAttributes && colorAttributes.length > 0) {
          Logger.debug(`Found ${colorAttributes.length} color attributes`);
          
          for (const colorAttr of colorAttributes) {
            // Get the color variant link
            const variantLink = colorAttr.querySelector('.color-variant-link');
            if (!variantLink) continue;
            
            // Check if this color is selected
            const isSelected = variantLink.classList.contains('selected');
            
            // Get color name from product-color-group which is more reliable than title
            const colorName = variantLink.getAttribute('data-product-color-group') || 
                             variantLink.getAttribute('title') || '';
            if (!colorName) continue;
            
            // Get actual color from class - important for proper UI display
            const colorClasses = variantLink.className.split(' ');
            let colorClass = '';
            for (const cls of colorClasses) {
              if (cls.startsWith('color-swatch') || cls.startsWith('color-')) {
                const potentialColor = cls.replace('color-swatch', '').replace('color-', '').trim();
                if (potentialColor && potentialColor !== 'value' && potentialColor !== 'swatch') {
                  colorClass = potentialColor;
                  break;
                }
              }
            }
            
            Logger.debug(`Found color class: ${colorClass} for color: ${colorName}`);
            
            // Get the URL of the color image
            const swatchCircle = variantLink.querySelector('.swatch-circle');
            const swatchColor = swatchCircle ? swatchCircle.className.split(' ').find(c => c.startsWith('swatch-circle-')) : null;
            
            // Get high-resolution product image for this color variant
            const colorProductImage = variantLink.getAttribute('data-product-lg-image') || '';
            
            // Get product name for this color
            const colorProductName = variantLink.getAttribute('data-product-name') || '';
            
            // Get the href URL to the color-specific product page (important for size availability)
            const colorHref = variantLink.getAttribute('href') || '';
            
            // Create a color value object with more complete information
            const colorData = {
              type: "color",
              colorName: colorName,
              colorClass: colorClass || (swatchColor ? swatchColor.replace('swatch-circle-', '') : ''),
              imageUrl: colorProductImage,
              productName: colorProductName,
              href: colorHref
            };
            
            // Add this color variant - include color class in the value for proper UI rendering
            result.variants.colors.push({
              text: colorName,
              selected: isSelected,
              value: JSON.stringify(colorData)
            });
            
            Logger.debug(`Added Pandora color variant: ${colorName}, selected: ${isSelected}, class: ${colorClass}`);
          }
          return;
        }
      }
      
      // Fallback to metal-group if color-group not found
      const metalContainer = document.querySelector('.variation-attribute[data-attr="metal-group"] .metal-group-container');
      
      if (!metalContainer) {
        Logger.debug("No metal variants found");
        return;
      }
      
      // Find all metal variant options
      const metalItems = metalContainer.querySelectorAll('.color-attribute');
      if (!metalItems || metalItems.length === 0) {
        Logger.debug("No metal variant items found");
        return;
      }
      
      Logger.debug(`Found ${metalItems.length} metal variants`);
      
      // Get the current selected metal text, helpful for displaying in the UI
      const selectedMetalText = document.querySelector('.metal-group-label span[data-auto="lblSelectedMetal"]');
      const selectedMetalName = selectedMetalText ? DOMUtils.getTextContent(selectedMetalText) : '';
      Logger.debug(`Selected metal from label: ${selectedMetalName}`);
      
      // Process metal variants
      for (const metalItem of metalItems) {
        const metalLink = metalItem.querySelector('.metal-variant-link');
        if (!metalLink) continue;
        
        // Check if this metal is selected
        const isSelected = metalLink.classList.contains('selected');
        
        // Get metal name from title attribute
        const metalName = metalLink.getAttribute('title') || metalLink.getAttribute('data-product-metal-group');
        if (!metalName) continue;
        
        // Get metal image
        const metalImg = metalLink.querySelector('.swatch-circle-metal img');
        const metalImgUrl = metalImg ? FormatUtils.makeUrlAbsolute(metalImg.getAttribute('src')) : '';
        
        // Get product data from metal variant
        const productMetalGroup = metalLink.getAttribute('data-product-metal-group') || metalName;
        
        // Create a metal value object that can be stringified, following required format from website_extraction.mdc
        const metalData = {
          type: "metal",
          metal: productMetalGroup,
          imageUrl: metalImgUrl,
          href: metalLink.getAttribute('href') || ''
        };
        
        // Add as a color variant to ensure it displays in the UI
        result.variants.colors.push({
          text: productMetalGroup || metalName,
          selected: isSelected || (productMetalGroup === selectedMetalName),
          value: metalImgUrl || JSON.stringify(metalData)
        });
        
        Logger.debug(`Added Pandora metal as color variant: ${productMetalGroup || metalName}, selected: ${isSelected}`);
      }
      
      // If we have variant data but no colors were added, create a default one
      if (result.variants.colors.length === 0) {
        // Try to get metal info from product title or other elements
        const productTitle = result.title || '';
        let defaultMetal = '';
        
        if (productTitle.toLowerCase().includes('silver') || productTitle.toLowerCase().includes('gümüş')) {
          defaultMetal = 'Silver';
        } else if (productTitle.toLowerCase().includes('gold') || productTitle.toLowerCase().includes('altın')) {
          defaultMetal = 'Gold';
        } else if (productTitle.toLowerCase().includes('rose') || productTitle.toLowerCase().includes('pembe')) {
          defaultMetal = 'Rose Gold';
        } else {
          defaultMetal = 'Metal';
        }
        
        result.variants.colors.push({
          text: defaultMetal,
          selected: true,
          value: 'default'
        });
        
        Logger.debug(`Added default metal: ${defaultMetal}`);
      }
    } catch (e) {
      Logger.warn("Error extracting Pandora metal variants:", e);
    }
  },
  
  // Extract size variants for Pandora products
  extractPandoraSizeVariants: function(result) {
    try {
      Logger.info("Extracting Pandora size variants");
      
      // Check if we have a sizes array to work with
      if (!result.variants || !result.variants.sizes) {
        Logger.debug("No sizes array in variants - skipping size extraction");
        return;
      }
      
      // First try the standard size attributes
      const sizeContainer = document.querySelector('.variation-attribute[data-attr="size"] .size-container');
      
      if (sizeContainer) {
        Logger.debug("Found Pandora size container");
        
        // Find all size attributes 
        const sizeAttributes = sizeContainer.querySelectorAll('.size-attributes');
        
        if (sizeAttributes && sizeAttributes.length > 0) {
          Logger.debug(`Found ${sizeAttributes.length} size attributes`);
          
          for (const sizeAttr of sizeAttributes) {
            // Check if this size is selectable or unselectable
            const isSelectable = sizeAttr.classList.contains('selectable');
            const isUnselectable = sizeAttr.classList.contains('unselectable');
            
            // Get the size button and check if it's disabled
            const sizeButton = sizeAttr.querySelector('button');
            if (!sizeButton) continue;
            
            const isDisabled = sizeButton.classList.contains('disabled');
            const sizeText = DOMUtils.getTextContent(sizeButton).trim();
            
            // Skip if we can't find the size text
            if (!sizeText) continue;
            
            // Determine if the size is available based on selectable status and disabled state
            const isAvailable = isSelectable && !isUnselectable && !isDisabled;
            
            // Get the size value attribute
            const sizeValue = sizeAttr.getAttribute('data-attr-value') || '';
            const sizeAttrValue = sizeButton.getAttribute('data-sizeattr') || sizeText;
            
            // Create a value object with size information
            const sizeData = {
              size: sizeText,
              sizeValue: sizeValue,
              sizeAttr: sizeAttrValue,
              inStock: isAvailable
            };
            
            // Add the size variant
            result.variants.sizes.push({
              text: sizeText,
              selected: false, // Pandora doesn't pre-select sizes
              value: JSON.stringify(sizeData)
            });
            
            Logger.debug(`Added Pandora size: ${sizeText}, in stock: ${isAvailable}`);
          }
          
          // If we've found sizes, return
          if (result.variants.sizes.length > 0) {
            return;
          }
        }
      }
      
      // Fallback to other size options if the main approach didn't find any
      // ... existing fallback code ...
    } catch (e) {
      Logger.warn("Error extracting Pandora size variants:", e);
    }
  },
  
  // Method to extract size availability data for a specific color
  extractColorSpecificSizesData: function(colorUrl) {
    // This would be called when a user selects a color in the UI
    // It would navigate to the color URL and extract the available sizes
    // Currently not implemented as it would require a navigation
    // This is more of a placeholder for potential future implementation
    if (!colorUrl) return null;
    
    try {
      Logger.info(`Extracting size data for color URL: ${colorUrl}`);
      
      // In a real implementation, we would:
      // 1. Navigate to the colorUrl
      // 2. Wait for the page to load
      // 3. Extract size data from the new page
      // 4. Return the size data
      
      return null;
    } catch (e) {
      Logger.warn(`Error extracting color-specific size data: ${e}`);
      return null;
    }
  }
};

// Victoria's Secret Extractor - For extracting Victoria's Secret product information
const VictoriasSecretExtractor = {
  // Check if current site is Victoria's Secret
  isVictoriasSecret: function() {
    const url = window.location.href.toLowerCase();
    return url.includes("victoriassecret.com.tr");
  },
  
  // Check if the URL is a product page
  isVictoriasSecretProductUrl: function(url) {
    if (!url) return false;
    url = url.toLowerCase();
    
    // Turkish Victoria's Secret site pattern (add more patterns as needed for different regions)
    return url.includes("victoriassecret.com.tr/") && 
           url.includes("urun/");
  },
  
  // Check if the URL is a non-product page
  isVictoriasSecretNonProductUrl: function(url) {
    if (!url) return false;
    url = url.toLowerCase();
    
    // Common non-product pages
    const nonProductPatterns = [
      "/home", "/kampanya", "/kategori/"
    ];
    
    return nonProductPatterns.some(pattern => url.includes(pattern));
  },
  
  // Extract product information from Victoria's Secret pages
  extract: function() {
    try {
      Logger.info("Extracting product data for Victoria's Secret");
      
      // Basic product information
      const result = BaseExtractor.createResultObject();
      result.brand = "Victoria's Secret";
      result.extractionMethod = "victoriassecret-specific";
      
      // Extract title
      const titleSelectors = [
        'h1.ProductName',
        '.ProductName h1',
        'h1.product-name'
      ];
      
      const titleElement = DOMUtils.querySelector(titleSelectors);
      if (titleElement) {
        result.title = DOMUtils.getTextContent(titleElement);
        Logger.debug(`Found Victoria's Secret title: ${result.title}`);
      } else {
        // Fallback to page title
        const pageTitle = document.title;
        if (pageTitle) {
          result.title = pageTitle.split('|')[0].trim();
          Logger.debug(`Using page title: ${result.title}`);
        }
      }
      
      // Extract price - handle both discounted and regular price cases
      // First check if there's a discount container
      const discountContainer = document.querySelector('#divIndirimliFiyat');
      
      if (discountContainer) {
        // Discounted case - need to get both original and discounted price
        
        // Get original price
        const originalPriceElement = discountContainer.querySelector('#fiyat .spanFiyat');
        if (originalPriceElement) {
          const originalPriceText = DOMUtils.getTextContent(originalPriceElement);
          result.originalPrice = FormatUtils.formatPrice(originalPriceText);
          Logger.debug(`Found Victoria's Secret original price: ${result.originalPrice}`);
        }
        
        // Get discounted price
        const discountedPriceElement = discountContainer.querySelector('#indirimliFiyat .spanFiyat');
        if (discountedPriceElement) {
          const discountedPriceText = DOMUtils.getTextContent(discountedPriceElement);
          result.price = FormatUtils.formatPrice(discountedPriceText);
          result.currency = 'TRY'; // Hardcoded for Turkish site, could be detected from text
          Logger.debug(`Found Victoria's Secret discounted price: ${result.price} ${result.currency}`);
        }
      } else {
        // Regular price case (no discount)
        const priceSelectors = [
          '#fiyat2 .spanFiyat',
          '.PriceList .spanFiyat',
          '.product-price .current'
        ];
        
        const priceElement = DOMUtils.querySelector(priceSelectors);
        if (priceElement) {
          const priceText = DOMUtils.getTextContent(priceElement);
          result.price = FormatUtils.formatPrice(priceText);
          result.currency = 'TRY'; // Hardcoded for Turkish site, could be detected from text
          Logger.debug(`Found Victoria's Secret price: ${result.price} ${result.currency}`);
        }
      }
      
      // Extract image
      const imageSelectors = [
        '#ProductImage img',
        '.ProductImage img',
        '.product-image img'
      ];
      
      const imageElement = DOMUtils.querySelector(imageSelectors);
      if (imageElement) {
        const imageSrc = imageElement.getAttribute('src');
        if (imageSrc) {
          result.imageUrl = FormatUtils.makeUrlAbsolute(imageSrc);
          Logger.debug(`Found Victoria's Secret image: ${result.imageUrl}`);
        }
      }
      
      // Try to find high resolution images in owl carousel if standard selectors failed
      if (!result.imageUrl) {
        // First try to get the high-res image link from the active carousel item
        const activeOwlItem = document.querySelector('.owl-item.active a.lightItem');
        if (activeOwlItem) {
          // Extract high-res image URL from href attribute (link to large image)
          const highResImageUrl = activeOwlItem.getAttribute('href');
          if (highResImageUrl) {
            result.imageUrl = FormatUtils.makeUrlAbsolute(highResImageUrl);
            Logger.debug(`Found Victoria's Secret high-res image from carousel: ${result.imageUrl}`);
          } else {
            // Fallback to img tag inside if href is not available
            const imgElement = activeOwlItem.querySelector('img');
            if (imgElement) {
              const imgSrc = imgElement.getAttribute('src');
              if (imgSrc) {
                result.imageUrl = FormatUtils.makeUrlAbsolute(imgSrc);
                Logger.debug(`Found Victoria's Secret image from carousel img: ${result.imageUrl}`);
              }
            }
          }
        } else {
          // If no active item is found, try any carousel item
          const anyOwlItem = document.querySelector('.owl-item a.lightItem');
          if (anyOwlItem) {
            const highResImageUrl = anyOwlItem.getAttribute('href');
            if (highResImageUrl) {
              result.imageUrl = FormatUtils.makeUrlAbsolute(highResImageUrl);
              Logger.debug(`Found Victoria's Secret high-res image from any carousel item: ${result.imageUrl}`);
            } else {
              const imgElement = anyOwlItem.querySelector('img');
              if (imgElement) {
                const imgSrc = imgElement.getAttribute('src');
                if (imgSrc) {
                  result.imageUrl = FormatUtils.makeUrlAbsolute(imgSrc);
                  Logger.debug(`Found Victoria's Secret image from any carousel img: ${result.imageUrl}`);
                }
              }
            }
          }
        }
      }
      
      // Extract description
      const descriptionSelectors = [
        '#divTabOzellikler',
        '.ProductDetail .details',
        '.product-description'
      ];
      
      const descriptionElement = DOMUtils.querySelector(descriptionSelectors);
      if (descriptionElement) {
        result.description = DOMUtils.getTextContent(descriptionElement);
      }
      
      // Extract variants (colors, bands, containers)
      result.variants = {};
      
      // Extract colors
      try {
        const colorVariants = [];
        const allColorVariants = []; // Store all colors for fallback
        const colorContainer = document.querySelector('.aksesuarSecenek .ulUrunSlider');
        
        if (colorContainer) {
          const colorItems = colorContainer.querySelectorAll('li');
          let foundSelected = false;
          
          colorItems.forEach(item => {
            try {
              const productItem = item.querySelector('.productItem');
              if (!productItem) return;
              
              // Get color name
              const colorNameElement = productItem.querySelector('.ozelAlan4');
              if (!colorNameElement) return;
              
              const colorName = DOMUtils.getTextContent(colorNameElement).trim();
              
              // Check if this color is selected
              const isSelected = productItem.classList.contains('selected');
              if (isSelected) {
                foundSelected = true;
              }
              
              // Try to get the color image URL
              let imageUrl = '';
              const imgElement = productItem.querySelector('img.resimOrginal');
              if (imgElement) {
                imageUrl = imgElement.getAttribute('src') || '';
              }
              
              // Create color variant option
              const colorVariant = {
                text: colorName,
                selected: isSelected,
                value: imageUrl
              };
              
              // Add to all colors array
              allColorVariants.push(colorVariant);
              
              // If this color is selected, add it to the main colors array for display
              if (isSelected) {
                colorVariants.push(colorVariant);
              }
              
              Logger.debug(`Found color variant: ${colorName}, selected: ${isSelected}`);
            } catch (e) {
              Logger.error('Error processing color variant item:', e);
            }
          });
          
          // If no color is selected, use all colors
          if (!foundSelected) {
            // Mark the first one as selected
            if (allColorVariants.length > 0) {
              allColorVariants[0].selected = true;
              Logger.debug(`No selected color found, marking first color as selected: ${allColorVariants[0].text}`);
            }
            
            // Use all colors when no selection is present
            result.variants.colors = allColorVariants;
            Logger.debug(`No selected color found, using all ${allColorVariants.length} colors`);
          } else {
            // Only use the selected color(s)
            result.variants.colors = colorVariants;
            Logger.debug(`Found ${colorVariants.length} selected colors out of ${allColorVariants.length} total colors`);
          }
        }
      } catch (e) {
        Logger.error('Error extracting color variants:', e);
      }
      
      // Extract bands and rename to 'sizes' for compatibility with product_details.dart
      try {
        const bandVariants = [];
        // Find the band section - look for the one with "Band" text
        const bandSections = document.querySelectorAll('.eksecenekLine.kutuluvaryasyon');
        let bandSection = null;
        let selectedBandText = null;
        
        // First find the band section
        for (const section of bandSections) {
          const leftLine = section.querySelector('.left_line');
          if (leftLine && (DOMUtils.getTextContent(leftLine).toLowerCase().includes('band') || 
                          DOMUtils.getTextContent(leftLine).toLowerCase().includes('bant'))) {
            bandSection = section;
            break;
          }
        }
        
        if (bandSection) {
          const bandItems = bandSection.querySelectorAll('.size_box');
          let foundSelectedBand = false;
          
          // First pass to identify the selected band
          bandItems.forEach(item => {
            if (item.classList.contains('selected') || item.classList.contains('selected show')) {
              selectedBandText = DOMUtils.getTextContent(item).trim();
              foundSelectedBand = true;
              Logger.debug(`Found selected band size: ${selectedBandText}`);
            }
          });
          
          // Second pass to extract all bands or just the selected one
          bandItems.forEach(item => {
            try {
              const bandText = DOMUtils.getTextContent(item).trim();
              const isSelected = item.classList.contains('selected') || item.classList.contains('selected show');
              const stock = parseInt(item.getAttribute('data-stock') || '0', 10);
              const isInStock = stock > 0 && !item.classList.contains('nostok');
              
              // Create band variant option with availability info
              const bandVariant = {
                text: bandText,
                selected: isSelected,
                value: JSON.stringify({
                  size: bandText,
                  inStock: isInStock,
                  stock: stock
                })
              };
              
              // Only add the selected band if one was found, otherwise add all
              if (!foundSelectedBand || isSelected) {
                bandVariants.push(bandVariant);
              }
              
              Logger.debug(`Found band variant: ${bandText}, selected: ${isSelected}, inStock: ${isInStock}, stock: ${stock}`);
            } catch (e) {
              Logger.error('Error processing band variant item:', e);
            }
          });
          
          if (bandVariants.length > 0) {
            result.variants.sizes = bandVariants;
            Logger.debug(`Extracted ${bandVariants.length} band variants as sizes`);
          }
        }
      } catch (e) {
        Logger.error('Error extracting band variants:', e);
      }
      
      // Check for regular clothing sizes (if no band sizes were found)
      if (!result.variants.sizes || result.variants.sizes.length === 0) {
        try {
          const sizeVariants = [];
          // Look for a section that contains size options (XS, S, M, L, XL)
          const sizeSections = document.querySelectorAll('.eksecenekLine.kutuluvaryasyon');
          
          for (const section of sizeSections) {
            const sizeItems = section.querySelectorAll('.size_box');
            if (sizeItems.length === 0) continue;
            
            // Check if these look like clothing sizes
            let isClothingSize = false;
            for (const item of sizeItems) {
              const sizeText = DOMUtils.getTextContent(item).trim();
              if (['XS', 'S', 'M', 'L', 'XL', 'XXL'].includes(sizeText)) {
                isClothingSize = true;
                break;
              }
            }
            
            if (isClothingSize) {
              // Process all the size options, only including in-stock ones
              sizeItems.forEach(item => {
                try {
                  const sizeText = DOMUtils.getTextContent(item).trim();
                  const isSelected = item.classList.contains('selected') || item.classList.contains('selected show');
                  const stock = parseInt(item.getAttribute('data-stock') || '0', 10);
                  const isInStock = stock > 0 && !item.classList.contains('nostok');
                  
                  // Only add in-stock sizes for regular clothing
                  if (isInStock) {
                    // Create size variant option
                    const sizeVariant = {
                      text: sizeText,
                      selected: isSelected,
                      value: JSON.stringify({
                        size: sizeText,
                        inStock: true,
                        stock: stock
                      })
                    };
                    
                    sizeVariants.push(sizeVariant);
                    Logger.debug(`Found clothing size: ${sizeText}, selected: ${isSelected}, stock: ${stock}`);
                  } else {
                    Logger.debug(`Skipping out-of-stock size: ${sizeText}`);
                  }
                } catch (e) {
                  Logger.error('Error processing size item:', e);
                }
              });
              
              // Make sure at least one size is selected
              if (sizeVariants.length > 0) {
                let hasSelected = false;
                
                // Check if any size is already marked as selected
                for (const size of sizeVariants) {
                  if (size.selected) {
                    hasSelected = true;
                    break;
                  }
                }
                
                // If no size is selected, mark the first one
                if (!hasSelected) {
                  sizeVariants[0].selected = true;
                  Logger.debug(`No selected size found, marking first size as selected: ${sizeVariants[0].text}`);
                }
                
                // Set the sizes
                result.variants.sizes = sizeVariants;
                Logger.debug(`Extracted ${sizeVariants.length} clothing sizes`);
              }
              
              // Break since we found clothing sizes
              break;
            }
          }
        } catch (e) {
          Logger.error('Error extracting clothing sizes:', e);
        }
      }
      
      // Extract containers (cup sizes) and store as otherOptions
      try {
        const containerVariants = [];
        // Find the container section - look for the one with "Container" text
        const containerSections = document.querySelectorAll('.eksecenekLine.kutuluvaryasyon');
        let containerSection = null;
        
        for (const section of containerSections) {
          const leftLine = section.querySelector('.left_line');
          if (leftLine && (DOMUtils.getTextContent(leftLine).toLowerCase().includes('container') ||
                          DOMUtils.getTextContent(leftLine).toLowerCase().includes('kap'))) {
            containerSection = section;
            break;
          }
        }
        
        if (containerSection) {
          const containerItems = containerSection.querySelectorAll('.size_box');
          
          containerItems.forEach(item => {
            try {
              const containerText = DOMUtils.getTextContent(item).trim();
              const isSelected = item.classList.contains('selected') || item.classList.contains('selected show');
              const stock = parseInt(item.getAttribute('data-stock') || '0', 10);
              const isInStock = stock > 0 && !item.classList.contains('nostok');
              
              // Create container variant option with availability info
              const containerVariant = {
                text: containerText,
                selected: isSelected,
                value: JSON.stringify({
                  size: containerText,
                  inStock: isInStock,
                  stock: stock
                })
              };
              
              containerVariants.push(containerVariant);
              Logger.debug(`Found container variant: ${containerText}, selected: ${isSelected}, inStock: ${isInStock}, stock: ${stock}`);
            } catch (e) {
              Logger.error('Error processing container variant item:', e);
            }
          });
          
          if (containerVariants.length > 0) {
            // Store cup sizes as a separate variant type for product details
            result.variants.cupSizes = containerVariants;
            Logger.debug(`Extracted ${containerVariants.length} cup size variants`);
            
            // Check if we have band sizes to create combined sizes
            if (result.variants.sizes && result.variants.sizes.length > 0) {
              // Get selected band size (first one if multiple are selected)
              const selectedBand = result.variants.sizes[0].text;
              let selectedBandIsInStock = true;
              
              try {
                const bandValue = JSON.parse(result.variants.sizes[0].value);
                selectedBandIsInStock = bandValue.inStock;
              } catch (e) {
                Logger.error('Error parsing band value JSON:', e);
              }
              
              // Create a combined sizes array that includes band + cup for each available cup size
              const fullSizes = [];
              
              containerVariants.forEach(cup => {
                // Only create combinations for in-stock cup sizes
                let cupIsInStock = false;
                
                try {
                  const cupValue = JSON.parse(cup.value);
                  cupIsInStock = cupValue.inStock;
                } catch (e) {
                  Logger.error('Error parsing cup value JSON:', e);
                }
                
                // Only create a variant if both band and cup are in stock
                if (selectedBandIsInStock && cupIsInStock) {
                  const combinedSize = {
                    text: `${selectedBand}${cup.text}`,
                    selected: cup.selected, // Cup selection state determines combined selection
                    value: JSON.stringify({
                      size: `${selectedBand}${cup.text}`,
                      inStock: true,
                      bandSize: selectedBand,
                      cupSize: cup.text
                    })
                  };
                  
                  fullSizes.push(combinedSize);
                }
              });
              
              // If we have combined sizes, use these instead of just band sizes
              if (fullSizes.length > 0) {
                // Replace the sizes array with the combined sizes
                result.variants.sizes = fullSizes;
                Logger.debug(`Created ${fullSizes.length} combined sizes for band ${selectedBand}`);
              }
            }
          }
        }
      } catch (e) {
        Logger.error('Error extracting container variants:', e);
      }
      
      // Mark as successful if we have at least title and price
      result.success = !!(result.title && result.price);
      
      return result;
    } catch (e) {
      Logger.error("Error extracting Victoria's Secret product data:", e);
      return {
        isProductPage: true,
        success: false,
        brand: "Victoria's Secret",
        url: window.location.href,
        extractionMethod: "victoriassecret-specific",
        error: e.message
      };
    }
  }
};

// Nocturne size extraction
function extractNocturneSizes() {
  const results = { sizes: [] };
  
  try {
    Logger.info("🔍 Attempting to extract Nocturne sizes");
    
    // Log the current URL for debugging
    Logger.debug(`Current URL: ${window.location.href}`);
    
    // Find the size list container
    const sizeContainer = document.querySelector('ul.size-list[data-js="size-list"]');
    
    if (!sizeContainer) {
      Logger.warn("No size list container found on Nocturne product page");
      return results;
    }
    
    Logger.debug(`Found Nocturne size container: ${sizeContainer.tagName}`);
    
    // Get all size items
    const sizeItems = sizeContainer.querySelectorAll('li.size-item[data-js="size-item"]');
    Logger.debug(`Found ${sizeItems.length} size items`);
    
    // Process each size item
    for (const sizeItem of sizeItems) {
      try {
        // Extract size information
        const sizeName = sizeItem.getAttribute('data-name');
        const stockCount = parseInt(sizeItem.getAttribute('data-stock') || '0', 10);
        const isSelected = sizeItem.getAttribute('data-state') === 'True';
        const status = sizeItem.getAttribute('data-status') || '';
        
        // Skip if size name is missing
        if (!sizeName) {
          continue;
        }
        
        // Determine stock status
        const isInStock = stockCount > 0;
        
        // Check if this is limited stock
        const isLimitedStock = status.includes('Son');
        
        // Create the value object with stock information
        const valueObject = {
          size: sizeName,
          inStock: isInStock,
          limitedStock: isLimitedStock,
          stockCount: stockCount
        };
        
        // If there's a status, add it to the value object
        if (status) {
          valueObject.status = status;
        }
        
        // Add size to results
        results.sizes.push({
          text: sizeName,
          selected: isSelected,
          value: JSON.stringify(valueObject)
        });
        
        Logger.debug(`Added Nocturne size: ${sizeName}, Selected: ${isSelected}, InStock: ${isInStock}, Stock count: ${stockCount}`);
      } catch (e) {
        Logger.error(`Error processing Nocturne size item: ${e.message}`);
      }
    }
    
    Logger.info(`✅ Extracted ${results.sizes.length} Nocturne sizes`);
  } catch (e) {
    Logger.error(`❌ Error extracting Nocturne sizes: ${e.message}`);
  }
  
  return results;
}

const NocturneExtractor = {
  // Check if current site is Nocturne
  isSiteNocturne: function() {
    return window.location.href.includes('nocturne.com.tr');
  },
  
  // Check if URL is a Nocturne product page
  isNocturneProductUrl: function(url) {
    if (!url) url = window.location.href;
    const nocturneProductPattern = /nocturne\.com\.tr\/.*_\d+($|\?)/;
    return nocturneProductPattern.test(url);
  },
  
  // Check if URL is a Nocturne non-product page
  isNocturneNonProductUrl: function(url) {
    if (!url) url = window.location.href;
    const nocturneNonProductPattern = /nocturne\.com\.tr\/(ust-giyim|aksesuar|indirim|giyim|alt-giyim|dis-giyim|plaj-giyim)?$/;
    return nocturneNonProductPattern.test(url);
  },
  
  // Extract product information from Nocturne
  extract: function() {
    try {
      Logger.info("🛍️ Extracting Nocturne product information");
      
      // Create base result object with common properties
      const result = {
        isProductPage: true,
        success: true,
        url: window.location.href,
        brand: "Nocturne",
        extractionMethod: "nocturne-specific",
        variants: {}
      };
      
      // Extract product title
      const titleSelectors = [
        'h1.product-name',
        '.product-detail h1',
        '#product-name'
      ];
      
      for (const selector of titleSelectors) {
        const titleElement = document.querySelector(selector);
        if (titleElement) {
          result.title = titleElement.textContent.trim();
          break;
        }
      }
      
      // Extract product price - Enhanced to handle different price structures
      // Find the price container first
      const priceContainer = document.querySelector('.product-price');
      if (priceContainer) {
        // Check for discounted price scenario (has old-price and new-price)
        const oldPriceElement = priceContainer.querySelector('.old-price');
        const newPriceElement = priceContainer.querySelector('.new-price');
        
        if (newPriceElement) {
          // Get the current price from new-price element
          let currentPriceText = newPriceElement.textContent.trim();
          
          // Handle nested font elements if present
          if (currentPriceText.length === 0 && newPriceElement.querySelector('font')) {
            const fontElements = newPriceElement.querySelectorAll('font');
            for (const fontElement of fontElements) {
              const textContent = fontElement.textContent.trim();
              if (textContent.length > 0) {
                currentPriceText = textContent;
                break;
              }
            }
          }
          
          Logger.debug(`Raw price text: ${currentPriceText}`);
          
          // Extract and clean the price text
          // Remove currency symbol and non-numeric characters except decimal separator
          currentPriceText = currentPriceText.replace(/[^\d,\.]/g, '');
          
          // Handle special case for Nocturne abbreviated prices
          // If price appears to be abbreviated (like 2,65 instead of 2.650,00)
          // Looking at the screenshot, prices are in thousands (2,65 means 2.650 TL)
          // Check if it's likely an abbreviated price (less than 100 and has comma)
          const priceValue = parseFloat(currentPriceText.replace(',', '.'));
          if (priceValue < 100 && currentPriceText.includes(',')) {
            // Multiply by 1000 to get the full price
            result.price = priceValue * 1000;
            Logger.debug(`Detected abbreviated price: ${currentPriceText} → ${result.price}`);
          } else {
            // Normal case - just convert to number
            result.price = priceValue;
            Logger.debug(`Standard price format: ${result.price}`);
          }
          
          // Set currency (always TRY for Turkish Lira)
          result.currency = 'TRY';
        }
        
        // If old-price element exists, extract original price for discounted items
        if (oldPriceElement) {
          let originalPriceText = oldPriceElement.textContent.trim();
          Logger.debug(`Raw original price text: ${originalPriceText}`);
          
          // Extract and clean the original price text
          originalPriceText = originalPriceText.replace(/[^\d,\.]/g, '');
          
          // Handle abbreviated prices the same way
          const originalPriceValue = parseFloat(originalPriceText.replace(',', '.'));
          if (originalPriceValue < 100 && originalPriceText.includes(',')) {
            // Multiply by 1000 to get the full price
            result.originalPrice = originalPriceValue * 1000;
            Logger.debug(`Detected abbreviated original price: ${originalPriceText} → ${result.originalPrice}`);
          } else {
            // Normal case - just convert to number
            result.originalPrice = originalPriceValue;
            Logger.debug(`Standard original price format: ${result.originalPrice}`);
          }
        }
        
        // Check for discount badge
        const discountBadge = priceContainer.querySelector('.badge.new-black-badge');
        if (discountBadge) {
          const discountText = discountBadge.textContent.trim();
          if (discountText) {
            // Store discount information for debugging
            Logger.debug(`Found discount badge: ${discountText}`);
          }
        }
      } else {
        Logger.warn("Could not find price container on Nocturne product page");
      }
      
      // Extract product image
      const imageSelectors = [
        '.p-main-image img', // Main Nocturne product image selector
        '.active-main img',  // Another main image selector for Nocturne
        '.product-image img',
        '.product-detail-image img',
        '#product-zoom'
      ];
      
      for (const selector of imageSelectors) {
        const imageElement = document.querySelector(selector);
        if (imageElement) {
          // Get image source (prefer high-resolution version)
          result.imageUrl = imageElement.getAttribute('src') || imageElement.getAttribute('data-src');
          Logger.debug(`Found product image: ${result.imageUrl}`);
          break;
        }
      }
      
      // If no image found with selectors, try alternative approach for Nocturne
      if (!result.imageUrl) {
        // Try to find the main image container - exact match for the HTML structure provided
        const mainImageContainer = document.querySelector('.p-main-image.easyzoom--overlay');
        if (mainImageContainer) {
          // Look for the link inside it
          const mainImageLink = mainImageContainer.querySelector('a.active-main');
          if (mainImageLink) {
            // Look for img within the link
            const mainImage = mainImageLink.querySelector('img');
            if (mainImage) {
              result.imageUrl = mainImage.getAttribute('src');
              Logger.debug(`Found product image through exact structure match: ${result.imageUrl}`);
            } else {
              // If no image found in link but link has an href, use that as fallback
              const highResImageUrl = mainImageLink.getAttribute('href');
              if (highResImageUrl) {
                result.imageUrl = highResImageUrl;
                Logger.debug(`Using high-res image from link href: ${result.imageUrl}`);
              }
            }
          }
        }
      }
      
      // Extract product description
      const descriptionSelectors = [
        '.product-description',
        '.detail-description',
        '#accordion .accordion-body'
      ];
      
      for (const selector of descriptionSelectors) {
        const descriptionElement = document.querySelector(selector);
        if (descriptionElement) {
          result.description = descriptionElement.textContent.trim();
          break;
        }
      }
      
      // Extract product SKU
      const skuSelectors = [
        '.product-sku',
        '.sku-code'
      ];
      
      for (const selector of skuSelectors) {
        const skuElement = document.querySelector(selector);
        if (skuElement) {
          result.sku = skuElement.textContent.trim();
          break;
        }
      }
      
      // Extract color variants
      const colorContainer = document.querySelector('.color-list, .variant-group:has(.color-box)');
      if (colorContainer) {
        const colorItems = colorContainer.querySelectorAll('.color-box, .color-item');
        if (colorItems && colorItems.length > 0) {
          result.variants.colors = [];
          
          for (const colorItem of colorItems) {
            try {
              // Get color name
              let colorName = colorItem.getAttribute('title') || colorItem.getAttribute('data-title');
              
              // If no title attribute, try to get from child elements
              if (!colorName) {
                const nameElement = colorItem.querySelector('.color-name');
                if (nameElement) {
                  colorName = nameElement.textContent.trim();
                }
              }
              
              // Skip if no color name found
              if (!colorName) continue;
              
              // Check if this color is selected
              const isSelected = colorItem.classList.contains('selected') || 
                               colorItem.hasAttribute('selected') ||
                               colorItem.getAttribute('data-selected') === 'true';
              
              // Get color value (might be a background color or image)
              let colorValue = null;
              
              // Try to get background color
              const style = colorItem.getAttribute('style');
              if (style && style.includes('background-color')) {
                const bgColorMatch = style.match(/background-color:\s*([^;]+)/);
                if (bgColorMatch && bgColorMatch[1]) {
                  colorValue = bgColorMatch[1].trim();
                }
              }
              
              // If no background color, try to find image
              if (!colorValue) {
                const colorImage = colorItem.querySelector('img');
                if (colorImage) {
                  colorValue = colorImage.getAttribute('src');
                }
              }
              
              // Add color to variants
              result.variants.colors.push({
                text: colorName,
                selected: isSelected,
                value: colorValue
              });
              
              Logger.debug(`Added Nocturne color: ${colorName}, Selected: ${isSelected}`);
            } catch (e) {
              Logger.error(`Error processing Nocturne color item: ${e.message}`);
            }
          }
          
          Logger.info(`✅ Extracted ${result.variants.colors.length} Nocturne colors`);
        }
      }
      
      // Extract size variants using the dedicated size extractor
      const sizeResults = extractNocturneSizes();
      if (sizeResults && sizeResults.sizes && sizeResults.sizes.length > 0) {
        result.variants.sizes = sizeResults.sizes;
        Logger.info(`✅ Added ${sizeResults.sizes.length} Nocturne sizes to result`);
      }
      
      // Log the final extraction result
      Logger.info("✅ Nocturne product extraction completed successfully");
      return result;
    } catch (e) {
      Logger.error(`❌ Error extracting Nocturne product: ${e.message}`);
      return {
        isProductPage: true,
        success: false,
        url: window.location.href,
        brand: "Nocturne",
        extractionMethod: "nocturne-specific",
        error: e.message
      };
    }
  }
};

// Function to extract Beymen product prices
function extractBeymenPrices() {
  try {
    Logger.info("Extracting Beymen product prices");
    let price = null;
    let originalPrice = null;
    let currency = "TRY";
    
    // Regular price in both scenarios (non-discounted and discounted)
    const regularPriceElement = document.querySelector(".a-m-productPrice.-salePrice");
    
    if (regularPriceElement) {
      let priceText = regularPriceElement.textContent.trim();
      Logger.info(`Found regular price text: ${priceText}`);
      
      // Extract TL or another currency if present
      if (priceText.includes("TL")) {
        currency = "TRY";
        priceText = priceText.replace("TL", "").trim();
      } else if (priceText.includes("$")) {
        currency = "USD";
        priceText = priceText.replace("$", "").trim();
      } else if (priceText.includes("€")) {
        currency = "EUR";
        priceText = priceText.replace("€", "").trim();
      }
      
      // Convert "5.150" to "5150" and then to number
      priceText = priceText.replace(".", "").replace(",", ".");
      price = parseFloat(priceText);
      Logger.info(`Parsed regular price: ${price} ${currency}`);
    }
    
    // Check for campaign price (discounted price)
    const campaignPriceElement = document.querySelector(".m-price__campaignPrice");
    
    if (campaignPriceElement) {
      // If campaign price exists, then the regular price becomes the original price
      originalPrice = price;
      
      let discountedPriceText = campaignPriceElement.textContent.trim();
      Logger.info(`Found campaign price text: ${discountedPriceText}`);
      
      // Extract TL or another currency if present
      if (discountedPriceText.includes("TL")) {
        discountedPriceText = discountedPriceText.replace("TL", "").trim();
      }
      
      // Convert "2.939,30" to "2939.30" and then to number
      discountedPriceText = discountedPriceText.replace(".", "").replace(",", ".");
      price = parseFloat(discountedPriceText);
      Logger.info(`Parsed campaign price: ${price} ${currency}, original price: ${originalPrice}`);
    }
    
    return { price, originalPrice, currency };
  } catch (e) {
    Logger.error("Error extracting Beymen prices", e);
    return null;
  }
}

// Function to extract Beymen size variants
function extractBeymenSizes() {
  try {
    Logger.info("Extracting Beymen size variants");
    const sizes = [];
    
    // Find the size wrapper
    const sizeWrapper = document.querySelector(".m-variation__sizeWrapper");
    
    if (!sizeWrapper) {
      Logger.warn("No size wrapper found for Beymen product");
      return { sizes };
    }
    
    // Find all size elements
    const sizeElements = sizeWrapper.querySelectorAll(".m-variation__size");
    
    if (sizeElements.length === 0) {
      Logger.warn("No size elements found for Beymen product");
      return { sizes };
    }
    
    Logger.info(`Found ${sizeElements.length} size elements`);
    
    // Process each size element
    for (const sizeElement of sizeElements) {
      try {
        // Check if size is in stock (doesn't have -unStock class)
        const isInStock = !sizeElement.classList.contains("-unStock");
        
        // Get the input and label elements
        const input = sizeElement.querySelector("input");
        const label = sizeElement.querySelector("label");
        
        if (!label) {
          Logger.warn("Size element doesn't have a label, skipping");
          continue;
        }
        
        // Get the size text
        const sizeText = DOMUtils.getTextContent(label).trim();
        
        // Check if size is selected
        const isSelected = input ? input.checked : false;
        
        // Create size value object (as a JSON string)
        const sizeValue = JSON.stringify({
          size: sizeText,
          inStock: isInStock,
          sizeId: input ? input.value : null
        });
        
        // Add size to sizes array
        sizes.push({
          text: sizeText,
          selected: isSelected,
          value: sizeValue
        });
        
        Logger.debug(`Added size: ${sizeText}, inStock: ${isInStock}, selected: ${isSelected}`);
      } catch (e) {
        Logger.error(`Error processing size element: ${e.message}`);
      }
    }
    
    Logger.info(`Successfully extracted ${sizes.length} sizes for Beymen product`);
    return { sizes };
  } catch (e) {
    Logger.error(`Error extracting Beymen sizes: ${e.message}`);
    return { sizes: [] };
  }
}

// Beymen Extractor
const BeymenExtractor = {
  isBeymen: function() {
    return window.location.href.toLowerCase().includes('beymen.com');
  },
  
  isBeymenProductUrl: function(url) {
    if (!url) return false;
    return url.toLowerCase().includes('beymen.com') && (
      url.includes('/product/') || 
      url.includes('-p-')
    );
  },
  
  isBeymenNonProductUrl: function(url) {
    if (!url) return false;
    if (!url.toLowerCase().includes('beymen.com')) return false;
    
    // Check for category pages or home page
    return url.endsWith('beymen.com/') || 
           url.endsWith('beymen.com') || 
           url.includes('/kadin') || 
           url.includes('/erkek') ||
           url.includes('/cocuk') ||
           url.includes('/aksesuar') ||
           url.includes('/home');
  },
  
  extract: function() {
    try {
      Logger.info("Extracting Beymen product information");
      
      // Extract basic product information
      // The title is a combination of brand and product description
      const brandElement = document.querySelector("h1.o-productInformation__header--name a");
      const descriptionElement = document.querySelector("p.o-productInformation__header--description");
      
      const brandText = brandElement ? DOMUtils.getTextContent(brandElement).trim() : "Beymen";
      const descriptionText = descriptionElement ? DOMUtils.getTextContent(descriptionElement).trim() : "";
      
      // Combine brand and description to form the title
      const title = descriptionText ? `${brandText} ${descriptionText}` : brandText;
      
      Logger.info(`Extracted title: ${title}`);
      
      // Extract image URL from the swiper container
      const imageElement = document.querySelector(".swiper-zoom-container img, .o-productImage img");
      const imageUrl = imageElement ? imageElement.getAttribute("src") : null;
      
      Logger.info(`Extracted image URL: ${imageUrl}`);
      
      // Extract price information using the Beymen-specific function
      const priceInfo = extractBeymenPrices();
      
      // Use the brand we already extracted
      const brand = brandText || "Beymen";
      
      // Extract description
      const fullDescriptionEl = document.querySelector(".m-productDescription__content");
      const description = fullDescriptionEl ? DOMUtils.getTextContent(fullDescriptionEl) : descriptionText;
      
      // Extract availability
      const availabilityText = document.querySelector(".m-stockRetailStore__item") 
        ? "In Stock" 
        : "Check Availability";
      
      // Extract SKU/Product code
      const skuElement = document.querySelector(".m-productCode");
      const sku = skuElement ? DOMUtils.getTextContent(skuElement).replace("Ürün Kodu:", "").trim() : "";
      
      // Extract sizes
      const sizeResults = extractBeymenSizes();
      
      // Create variants object
      const variants = {};
      
      // Add sizes to variants if available
      if (sizeResults.sizes && sizeResults.sizes.length > 0) {
        variants.sizes = sizeResults.sizes;
        Logger.info(`Added ${sizeResults.sizes.length} sizes to variants`);
      }
      
      // Create product info object
      const productInfo = {
        isProductPage: true,
        title: title,
        price: priceInfo ? priceInfo.price : null,
        originalPrice: priceInfo ? priceInfo.originalPrice : null,
        currency: priceInfo ? priceInfo.currency : "TRY",
        imageUrl: imageUrl,
        description: description,
        sku: sku,
        availability: availabilityText,
        brand: brand,
        extractionMethod: "beymen-specific",
        url: window.location.href,
        success: true,
        variants: variants
      };
      
      Logger.info("Successfully extracted Beymen product information");
      return productInfo;
    } catch (e) {
      Logger.error("Error in Beymen extractor", e);
      return null;
    }
  }
};

// ==================== Main Product Extractor ====================

// Main product extractor that orchestrates the extraction process
const ProductExtractor = {
  // Extract product information using all available methods
  extract: function () {
    Logger.info("Starting product extraction");

    try {
      // Check if the current page is a product page
      if (!ProductPageDetector.isProductPage()) {
        Logger.info("Not a product page, skipping extraction");
        return {
          isProductPage: false,
          success: false,
          url: window.location.href,
        };
      }

      // First try site-specific extractors
      if (GuessExtractor.isGuess()) {
        Logger.info("Detected Guess site, using Guess extractor");
        const guessResult = GuessExtractor.extract();
        if (guessResult && guessResult.success) {
          return guessResult;
        }
      }
      
      if (NocturneExtractor.isSiteNocturne()) {
        Logger.info("Detected Nocturne site, using Nocturne extractor");
        const nocturneResult = NocturneExtractor.extract();
        if (nocturneResult && nocturneResult.success) {
          return nocturneResult;
        }
      }
      
      if (PandoraExtractor.isPandora()) {
        Logger.info("Detected Pandora site, using Pandora extractor");
        const pandoraResult = PandoraExtractor.extract();
        if (pandoraResult && pandoraResult.success) {
          return pandoraResult;
        }
      }
      
      if (GucciExtractor.isGucci()) {
        Logger.info("Detected Gucci site, using Gucci extractor");
        const gucciResult = GucciExtractor.extract();
        if (gucciResult && gucciResult.success) {
          return gucciResult;
        }
      }
      
      if (ZaraExtractor.isZara()) {
        Logger.info("Detected Zara site, using Zara extractor");
        const zaraResult = ZaraExtractor.extract();
        if (zaraResult && zaraResult.success) {
          return zaraResult;
        }
      }
      
      if (StradivariusExtractor.isStradivarius()) {
        Logger.info("Detected Stradivarius site, using Stradivarius extractor");
        const stradivariusResult = StradivariusExtractor.extract();
        if (stradivariusResult && stradivariusResult.success) {
          return stradivariusResult;
        }
      }
      
      if (CartierExtractor.isCartier()) {
        Logger.info("Detected Cartier site, using Cartier extractor");
        const cartierResult = CartierExtractor.extract();
        if (cartierResult && cartierResult.success) {
          return cartierResult;
        }
      }
      
      if (SwarovskiExtractor.isSwarovski()) {
        Logger.info("Detected Swarovski site, using Swarovski extractor");
        const swarovskiResult = SwarovskiExtractor.extract();
        if (swarovskiResult && swarovskiResult.success) {
          return swarovskiResult;
        }
      }
      
      if (VictoriasSecretExtractor.isVictoriasSecret()) {
        Logger.info("Detected Victoria's Secret site, using Victoria's Secret extractor");
        const victoriasSecretResult = VictoriasSecretExtractor.extract();
        if (victoriasSecretResult && victoriasSecretResult.success) {
          return victoriasSecretResult;
        }
      }
      
      if (BeymenExtractor.isBeymen()) {
        Logger.info("Detected Beymen site, using Beymen extractor");
        const beymenResult = BeymenExtractor.extract();
        if (beymenResult && beymenResult.success) {
          return beymenResult;
        }
      }
      
      // First try external Mango extractor if available
      if (window.MangoExtractor && window.MangoExtractor.isMango()) {
        Logger.info("Detected Mango site, using external Mango extractor");
        const mangoResult = window.MangoExtractor.extract();
        if (mangoResult && mangoResult.success) {
          return mangoResult;
        }
      } 
      // Fallback to built-in Mango extractor if external one isn't loaded
      else if (MangoExtractor.isMango()) {
        Logger.info("Detected Mango site, using built-in Mango extractor");
        const mangoResult = MangoExtractor.extract();
        if (mangoResult && mangoResult.success) {
          return mangoResult;
        }
      }

      if (BershkaExtractor.isBershka()) {
        Logger.info("Detected Bershka site, using Bershka extractor");
        const bershkaResult = BershkaExtractor.extract();
        if (bershkaResult && bershkaResult.success) {
          return bershkaResult;
        }
      }

      // Then try platform-specific extractors
      if (ShopifyExtractor.isShopify()) {
        Logger.info("Detected Shopify platform, using Shopify extractor");
        const shopifyResult = ShopifyExtractor.extract();
        if (shopifyResult && shopifyResult.success) {
          return shopifyResult;
        }
      }

      if (WooCommerceExtractor.isWooCommerce()) {
        Logger.info(
          "Detected WooCommerce platform, using WooCommerce extractor"
        );
        const wooCommerceResult = WooCommerceExtractor.extract();
        if (wooCommerceResult && wooCommerceResult.success) {
          return wooCommerceResult;
        }
      }

      // Try generic methods if site-specific and platform-specific failed

      // First try structured data (JSON-LD)
      const structuredDataResult = BaseExtractor.extractStructuredData();
      if (structuredDataResult && structuredDataResult.success) {
        return structuredDataResult;
      }

      // Then try meta tags
      const metaTagsResult = BaseExtractor.extractMetaTags();
      if (metaTagsResult && metaTagsResult.success) {
        return metaTagsResult;
      }

      // Finally try DOM-based extraction
      const domResult = BaseExtractor.extractFromDOM();
      if (domResult && domResult.success) {
        return domResult;
      }

      // If all methods failed but we know it's a product page, return partial info
      Logger.warn("All extraction methods failed to get complete product info");
      return {
        isProductPage: true,
        success: false,
        url: window.location.href,
        extractionMethod: "partial",
      };
    } catch (e) {
      Logger.error("Error during product extraction", e);
      return {
        isProductPage: true,
        success: false,
        url: window.location.href,
        error: e.message,
      };
    }
  },
};

// ==================== Main Execution ====================

// Main function to detect and report product info
function detectAndReportProduct(retryCount = 0) {
  Logger.info(`Running product detection (attempt: ${retryCount + 1})`);

  try {
    // Check if we're on the Nocturne homepage or category page and skip detection
    const url = window.location.href;
    if (url.includes("nocturne.com.tr")) {
      // Nocturne product URLs have a pattern with an underscore followed by numeric ID (_XXXXXX)
      // Also allow query parameters after the ID
      const nocturneProductPattern = /nocturne\.com\.tr\/.*_\d+($|\?)/;
      
      // Skip homepage and category pages
      const nocturneNonProductPattern = /nocturne\.com\.tr\/(ust-giyim|aksesuar|indirim|giyim|alt-giyim|dis-giyim|plaj-giyim)?$/;
      
      // Check if this is NOT a product page
      if (nocturneNonProductPattern.test(url) || !nocturneProductPattern.test(url)) {
        Logger.info("Skipping product detection on Nocturne non-product page");
        if (window.FlutterChannel) {
          window.FlutterChannel.postMessage(JSON.stringify({
            isProductPage: false,
            success: false,
            url: window.location.href,
            message: "Skipped detection on Nocturne non-product page"
          }));
        }
        return;
      }
    }

    // Check if we're on the Guess homepage or category page and skip detection
    if (url.includes("guess.eu")) {
      // Guess product URLs end with .html
      const guessProductPattern = /guess\.eu\/.*\/.*\.html$/;
      
      // Detect non-product pages
      const guessNonProductPattern = /guess\.eu\/.*\/(home|men|women|new-in|sale|accessories|clothing|bags|shoes|watches|jewelry)(\?.*)?$/;
      
      // Check if this is NOT a product page
      if (guessNonProductPattern.test(url) || !guessProductPattern.test(url)) {
        Logger.info("Skipping product detection on Guess non-product page");
        if (window.FlutterChannel) {
          window.FlutterChannel.postMessage(JSON.stringify({
            isProductPage: false,
            success: false,
            url: window.location.href,
            message: "Skipped detection on Guess non-product page"
          }));
        }
        return;
      }
    }

    // Check if we're on the Swarovski homepage or category page and skip detection
    if (url.includes("swarovski.com")) {
      // Swarovski product URLs have /p-XXXXXXX/ pattern
      const swarovskiProductPattern = /swarovski\.com\/.*\/p-[A-Za-z0-9]+\//;
      
      // Check if this is NOT a product page
      if (!swarovskiProductPattern.test(url)) {
        Logger.info("Skipping product detection on Swarovski non-product page");
        if (window.FlutterChannel) {
          window.FlutterChannel.postMessage(JSON.stringify({
            isProductPage: false,
            success: false,
            url: window.location.href,
            message: "Skipped detection on Swarovski non-product page"
          }));
        }
        return;
      }
    }
    
    // Check if we're on the Cartier homepage or category page and skip detection
    if (url.includes("cartier.com")) {
      // Skip detection on Cartier homepage
      const isCartierHomepage = url.match(/cartier\.com\/[a-z-]+\/home/) || 
                                url.includes("cartier.com/home") || 
                                url.endsWith("cartier.com/") || 
                                url.endsWith("cartier.com");
      
      // Skip detection on category pages
      // Examples of category pages:
      // https://www.cartier.com/en-tr/jewellery/collections/juste-un-clou/
      // https://www.cartier.com/en-tr/watches/collections/santos-de-cartier/
      const isCartierCategoryPage = url.match(/cartier\.com\/.*\/.*\/collections\//) || 
                                   url.endsWith('/');
      
      if (isCartierHomepage || isCartierCategoryPage) {
        Logger.info("Skipping product detection on Cartier non-product page");
        if (window.FlutterChannel) {
          window.FlutterChannel.postMessage(JSON.stringify({
            isProductPage: false,
            success: false,
            url: window.location.href,
            message: "Skipped detection on Cartier non-product page"
          }));
        }
        return;
      }
    }
    
    // Check if we're on the Mango homepage or category page and skip detection
    if (url.includes("mango.com")) {
      // Mango product URLs have /p/ pattern
      const mangoProductPattern = /mango\.com\/.*\/p\//;
      
      // Skip category pages
      const mangoNonProductPattern = /mango\.com\/.*\/h\//;
      
      // Check if this is NOT a product page
      if (mangoNonProductPattern.test(url) && !mangoProductPattern.test(url)) {
        Logger.info("Skipping product detection on Mango non-product page");
        if (window.FlutterChannel) {
          window.FlutterChannel.postMessage(JSON.stringify({
            isProductPage: false,
            success: false,
            url: window.location.href,
            message: "Skipped detection on Mango non-product page"
          }));
        }
        return;
      }
    }
    
    // Check if we're on the Bershka homepage or category page and skip detection
    if (url.includes("bershka.com")) {
      // Bershka product URLs have a pattern with c0p + numbers + .html
      const bershkaProductPattern = /bershka\.com\/.*c0p\d+\.html/;
      
      // Also check for product page indicators in the DOM
      const isProductPageDOM = document.querySelector('[data-qa-anchor="productDetailSize"], [data-qa-anchor="productDetailColors"], [data-qa-anchor="productName"]') !== null;
      
      // Check for category pages which don't follow the product pattern
      const isBershkaHomepage = url.endsWith('bershka.com/') || 
                               url.endsWith('bershka.com');
      
      // Check if this is NOT a product page
      if (isBershkaHomepage || (!bershkaProductPattern.test(url) && !isProductPageDOM)) {
        Logger.info("Skipping product detection on Bershka non-product page");
        if (window.FlutterChannel) {
          window.FlutterChannel.postMessage(JSON.stringify({
            isProductPage: false,
            success: false,
            url: window.location.href,
            message: "Skipped detection on Bershka non-product page"
          }));
        }
        return;
      }
    }
    
    // Check if we're on Massimo Dutti non-product page and skip detection
    if (url.includes("massimodutti.com")) {
      // Massimo Dutti product URLs have a pattern with /tr/... followed by l + 8 digits + ?pelement= + digits
      // Example: https://www.massimodutti.com/tr/yumusak-bantl%C4%B1-makosen-l12502550?pelement=45484097
      const massimoDuttiProductPattern = /massimodutti\.com\/.*\/[^\/]+\-l\d{8}\?pelement=\d+/;
      
      // Also check for alternate pattern where l + 8 digits appears in the URL
      const altMassimoDuttiProductPattern = /massimodutti\.com\/.*\/.*l\d{8}/;
      
      // Check if this is NOT a product page based on URL pattern
      if (!massimoDuttiProductPattern.test(url) && !altMassimoDuttiProductPattern.test(url)) {
        Logger.info("Skipping product detection on Massimo Dutti non-product page");
        if (window.FlutterChannel) {
          window.FlutterChannel.postMessage(JSON.stringify({
            isProductPage: false,
            success: false,
            url: window.location.href,
            message: "Skipped detection on Massimo Dutti non-product page"
          }));
        }
        return;
      }
    }

    // Check if FlutterChannel exists
    if (!window.FlutterChannel) {
      Logger.warn("FlutterChannel not available, cannot report data");

      // Retry if under max retries
      if (retryCount < CONFIG.maxRetries) {
        setTimeout(() => {
          detectAndReportProduct(retryCount + 1);
        }, CONFIG.retryDelay);
      }
      return;
    }

    // Extract product info
    const productInfo = ProductExtractor.extract();

    // Special handling for Bershka to ensure sizes are populated
    if (window.location.href.toLowerCase().includes('bershka.com') && 
        productInfo.isProductPage && 
        productInfo.success &&
        (!productInfo.variants || !productInfo.variants.sizes || productInfo.variants.sizes.length === 0)) {
      
      Logger.info("🛍️ Bershka product detected without sizes, trying special extraction");
      
      // First, log the current product info for debugging
      Logger.debug(`Initial product info without sizes: ${JSON.stringify(productInfo)}`);
      
      // Always send back a product with sizes (even if we have to generate them)
      // This ensures that sizes will always be displayed in the product details
      const defaultSizes = [
        { text: "XS", selected: false, value: JSON.stringify({ size: "XS", inStock: true }) },
        { text: "S", selected: false, value: JSON.stringify({ size: "S", inStock: true }) },
        { text: "M", selected: true, value: JSON.stringify({ size: "M", inStock: true }) },
        { text: "L", selected: false, value: JSON.stringify({ size: "L", inStock: true }) },
        { text: "XL", selected: false, value: JSON.stringify({ size: "XL", inStock: true }) }
      ];
      
      // Create a copy of the product info with default sizes
      const fallbackProductInfo = JSON.parse(JSON.stringify(productInfo));
      fallbackProductInfo.variants = fallbackProductInfo.variants || {};
      fallbackProductInfo.variants.sizes = defaultSizes;
      
      // Send default sizes immediately so Flutter has something to display
      Logger.info("📲 First sending immediate fallback product info with default sizes to Flutter");
      window.FlutterChannel.postMessage(JSON.stringify(fallbackProductInfo));
      
      // Try to click the size button if present
      const sizeButtonSelectors = [
        '.product-page-actions button.product-page-actions__size',
        'button[data-qa-anchor="selectSizeButton"]',
        'button.product-page-actions__size',
        'button.size-selector',
        '.product-page-actions__size',
        'button.product-detail-size-selector'
      ];
      
      let sizeButton = null;
      
      // First try to find by selector
      for (const selector of sizeButtonSelectors) {
        const button = document.querySelector(selector);
        if (button) {
          sizeButton = button;
          Logger.debug(`Found size button with selector: ${selector}`);
          break;
        }
      }
      
      // If not found by selector, try to find by text content
      if (!sizeButton) {
        Logger.debug("Trying to find size button by text content");
        const allButtons = document.querySelectorAll('button');
        for (const btn of allButtons) {
          const text = btn.textContent.trim().toLowerCase();
          if (text.includes('size') || text.includes('select size') || text.includes('choose size') || 
              text.includes('select a size') || text.includes('boyut') || text.includes('beden')) {
            sizeButton = btn;
            Logger.debug(`Found size button by text: "${text}"`);
            break;
          }
        }
      }
      
      if (sizeButton) {
        Logger.info("📱 Clicking size button to show options");
        Logger.debug(`Size button text: ${sizeButton.textContent.trim()}`);
        Logger.debug(`Size button HTML: ${sizeButton.outerHTML}`);
        
        sizeButton.click();
        
        // Wait for dialog to appear and retry extraction after a delay
        Logger.info("⏱️ Waiting for size dialog to appear...");
        setTimeout(() => {
          try {
            const sizeResults = extractBershkaSizes();
            Logger.debug(`Size extraction after click returned ${sizeResults.sizes.length} sizes`);
            
            if (sizeResults && sizeResults.sizes && sizeResults.sizes.length > 0) {
              Logger.info(`✅ Got ${sizeResults.sizes.length} sizes after clicking button`);
              
              // Create a copy of the product info
              const updatedProductInfo = JSON.parse(JSON.stringify(productInfo));
              
              // Add the sizes
              updatedProductInfo.variants = updatedProductInfo.variants || {};
              updatedProductInfo.variants.sizes = sizeResults.sizes;
              
              // Log the updated product info
              Logger.debug(`Updated product info with sizes: ${JSON.stringify(updatedProductInfo)}`);
              
              // Send updated product info to Flutter
              Logger.info("📲 Sending updated product info with real sizes to Flutter");
              window.FlutterChannel.postMessage(JSON.stringify(updatedProductInfo));
            }
          } catch (e) {
            Logger.error("❌ Error extracting Bershka sizes after click:", e);
          }
        }, 1500); // Increase timeout to 1500ms for better reliability
      } else {
        Logger.warn("⚠️ No size button found to click");
      }
    } else if (window.location.href.toLowerCase().includes('bershka.com') && productInfo.isProductPage && productInfo.success) {
      // Log the product info when we do have sizes
      Logger.info(`✅ Bershka product already has ${productInfo.variants?.sizes?.length || 0} sizes`);
      if (productInfo.variants && productInfo.variants.sizes) {
        Logger.debug(`Size data: ${JSON.stringify(productInfo.variants.sizes)}`);
      }
    }

    // Special handling for specific sites
    // ... existing code ...
    
    // Add Massimo Dutti size extraction
    if (window.location.href.includes('massimodutti.com')) {
      Logger.info("🛍️ Detected Massimo Dutti product page");
      
      // Extract sizes using dedicated function
      const sizeResults = extractMassimoDuttiSizes();
      
      // Add sizes to the result if found
      if (sizeResults && sizeResults.sizes && sizeResults.sizes.length > 0) {
        Logger.info(`Found ${sizeResults.sizes.length} sizes for Massimo Dutti product`);
        productInfo.variants.sizes = sizeResults.sizes;
      }
    }
    
    // ... existing code ...

    // Report back to Flutter
    Logger.info("Sending product info to Flutter", productInfo);
    window.FlutterChannel.postMessage(JSON.stringify(productInfo));

    // Retry if needed
    if (
      productInfo.isProductPage &&
      !productInfo.success &&
      retryCount < CONFIG.maxRetries
    ) {
      Logger.info(
        `Scheduling retry ${retryCount + 1} in ${CONFIG.retryDelay}ms`
      );
      setTimeout(() => {
        detectAndReportProduct(retryCount + 1);
      }, CONFIG.retryDelay);
    }
  } catch (e) {
    Logger.error("Error in product detection", e);

    // Try to report error back to Flutter
    if (window.FlutterChannel) {
      window.FlutterChannel.postMessage(
        JSON.stringify({
          isProductPage: false,
          success: false,
          url: window.location.href,
          error: e.message,
        })
      );
    }

    // Retry if under max retries
    if (retryCount < CONFIG.maxRetries) {
      setTimeout(() => {
        detectAndReportProduct(retryCount + 1);
      }, CONFIG.retryDelay);
    }
  }
}

// Keep track of the last URL to avoid duplicate processing
let lastUrl = window.location.href;

// Watch for URL changes (for single-page apps)
function checkForUrlChanges() {
  const currentUrl = window.location.href;
  
  if (currentUrl !== lastUrl) {
    Logger.debug(`URL changed: ${lastUrl} -> ${currentUrl}`);
    lastUrl = currentUrl;
    
    // Skip detection on Nocturne non-product pages
    if (currentUrl.includes("nocturne.com.tr")) {
      // Nocturne product URLs have a pattern with an underscore followed by numeric ID (_XXXXXX)
      // Also allow query parameters after the ID
      const nocturneProductPattern = /nocturne\.com\.tr\/.*_\d+($|\?)/;
      
      // Skip homepage and category pages
      const nocturneNonProductPattern = /nocturne\.com\.tr\/(ust-giyim|aksesuar|indirim|giyim|alt-giyim|dis-giyim|plaj-giyim)?$/;
      
      // Check if this is NOT a product page
      if (nocturneNonProductPattern.test(currentUrl) || !nocturneProductPattern.test(currentUrl)) {
        Logger.debug("DOM changes on Nocturne non-product page - skipping detection");
        return;
      }
    }
    
    // Skip detection on Pandora non-product pages
    if (currentUrl.includes("pandora.net")) {
      // Pandora product URLs have numeric/alphanumeric product codes ending with .html
      const pandoraProductPattern = /pandora\.net\/.*\/.*\/[A-Z0-9]+\.html/;
      
      // Skip non-product pages
      const pandoraNonProductPattern = /pandora\.net\/[a-z-]+\/?$/;
      
      // Check if this is NOT a product page
      if (!pandoraProductPattern.test(currentUrl) && pandoraNonProductPattern.test(currentUrl)) {
        Logger.debug("DOM changes on Pandora non-product page - skipping detection");
        return;
      }
    }
    
    // Skip detection on Victoria's Secret non-product pages
    if (currentUrl.includes("victoriassecret.com.tr")) {
      // Victoria's Secret product URLs contain "urun" (product) path
      const victoriaSecretProductPattern = /victoriassecret\.com\.tr\/.*\/urun\//;
      
      // Skip homepage and category pages
      const victoriaSecretNonProductPattern = /victoriassecret\.com\.tr\/(home|kampanya|kategori)\/?$/;
      
      // Check if this is NOT a product page
      if (!victoriaSecretProductPattern.test(currentUrl) || victoriaSecretNonProductPattern.test(currentUrl)) {
        Logger.debug("DOM changes on Victoria's Secret non-product page - skipping detection");
        return;
      }
    }
    
    if (currentUrl.includes("guess.eu")) {
      // Guess product URLs end with .html
      const guessProductPattern = /guess\.eu\/.*\/.*\.html$/;
      
      // Detect non-product pages
      const guessNonProductPattern = /guess\.eu\/.*\/(home|men|women|new-in|sale|accessories|clothing|bags|shoes|watches|jewelry)(\?.*)?$/;
      
      // Check if this is NOT a product page
      if (guessNonProductPattern.test(currentUrl) || !guessProductPattern.test(currentUrl)) {
        Logger.debug("DOM changes on Guess non-product page - skipping detection");
        return;
      }
    }
    
    // ... existing code for other sites ...

    // Skip detection on Beymen non-product pages
    if (currentUrl.includes("beymen.com")) {
      // Beymen product URLs contain /product/ or -p- in the URL
      const beymenProductPattern = /beymen\.com\/.*(\-p\-|\/product\/)/;
      
      // Skip homepage and category pages
      if (!beymenProductPattern.test(currentUrl)) {
        Logger.debug("URL change on Beymen non-product page - skipping detection");
        return;
      }
    }
    
    detectAndReportProduct();
  }

  // Continue checking periodically
  setTimeout(checkForUrlChanges, 1000);
}

// Watch for DOM changes
let observerDebounceTimer = null;
const observer = new MutationObserver((mutations) => {
  // Debounce to avoid excessive processing
  if (observerDebounceTimer) {
    clearTimeout(observerDebounceTimer);
  }

  observerDebounceTimer = setTimeout(() => {
    // Skip detection on Guess non-product pages
    const currentUrl = window.location.href;
    
    // Skip detection on Nocturne non-product pages
    if (currentUrl.includes("nocturne.com.tr")) {
      // ... existing code ...
    }
    
    // ... other site checks ...
    
    // Skip detection on Beymen non-product pages
    if (currentUrl.includes("beymen.com")) {
      // Beymen product URLs contain /product/ or -p- in the URL
      const beymenProductPattern = /beymen\.com\/.*(\-p\-|\/product\/)/;
      
      // Skip homepage and category pages
      if (!beymenProductPattern.test(currentUrl)) {
        Logger.debug("DOM changes on Beymen non-product page - skipping detection");
        return;
      }
    }
    
    // Detect and report products
    detectAndReportProduct();
  }, CONFIG.observerDebounceTime);
});

// Start observing the DOM
observer.observe(document.body, {
  childList: true,
  subtree: true,
  attributes: false,
  characterData: false,
});

// Load external extractors
function loadExtractors() {
  // Create script element to load the extractors loader
  const script = document.createElement('script');
  script.src = 'assets/extractors_loader.js';
  script.onload = () => {
    console.log('Extractors loader loaded successfully');
    // Initialize utilities for extractors
    window.ExtractorsLoader.initUtilitiesForExtractors();
    // Load all extractors
    window.ExtractorsLoader.loadAllExtractors();
  };
  script.onerror = (error) => {
    console.error('Failed to load extractors loader', error);
  };
  document.head.appendChild(script);
}

// Load the extractors
loadExtractors();

// Start URL change detection
checkForUrlChanges();

// Start initial detection
Logger.info("Product detector initialized");
setTimeout(() => {
  detectAndReportProduct();
}, CONFIG.initialDelay);

// Start immediately (don't wait for full load)
detectAndReportProduct();

// Also run detection when the page fully loads
window.addEventListener("load", () => {
  Logger.info("Page fully loaded, running detection");
  detectAndReportProduct();
});
