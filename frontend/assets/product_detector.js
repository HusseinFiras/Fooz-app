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
            value: imageUrl || colorText,
            imageUrl: imageUrl, // Also store the image URL separately
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
      if (GucciExtractor.isGucci()) {
        Logger.info("Detected Gucci site, using Gucci extractor");
        const gucciResult = GucciExtractor.extract();
        if (gucciResult && gucciResult.success) {
          return gucciResult;
        }
      }

      // Check for Zara site
      if (ZaraExtractor.isZara()) {
        Logger.info("Detected Zara site, using Zara extractor");
        const zaraResult = ZaraExtractor.extract();
        if (zaraResult && zaraResult.success) {
          return zaraResult;
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
    Logger.info(`URL changed to: ${currentUrl}`);
    lastUrl = currentUrl;
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
    Logger.debug("DOM changes detected, checking for product info");
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
