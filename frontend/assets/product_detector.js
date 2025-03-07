/**
 * Advanced Product Detection Script for E-commerce WebViews
 *
 * This script uses multiple detection methods to:
 * 1. Identify if the current page is a product page
 * 2. Extract product information using structured data, meta tags, and DOM analysis
 * 3. Monitor for changes and page navigation
 * 4. Send structured data back to Flutter
 */

// Initialize the product detector when the script is loaded
(function () {
  // Start script with shorter delay to be more responsive
  setTimeout(initProductDetector, 500); // Reduced from 1000ms
})();

/**
 * Main function to initialize product detection
 */
function initProductDetector() {
  // Configuration - optimized timing values
  const CHECK_INTERVAL = 800; // Reduced from 1000ms
  const MAX_RETRIES = 5; // Reduced from 8
  const RETRY_DELAY = 600; // Reduced from 800ms
  const NAVIGATION_CHECK_INTERVAL = 300; // Reduced from 500ms

  let retryCount = 0;
  let lastProductData = null;
  let productDetected = false;
  let observer = null;
  let initialAttemptComplete = false;

  // Function to report data back to Flutter
  function reportToFlutter(data) {
    if (window.FlutterChannel) {
      window.FlutterChannel.postMessage(JSON.stringify(data));
    }
  }

  // Main product detection function
  function detectAndReportProduct() {
    const productData = extractProductInfo();

    // If we've already detected and reported this product, don't report again
    // unless something significant changed
    if (lastProductData && productData.success) {
      if (
        lastProductData.title === productData.title &&
        lastProductData.price === productData.price
      ) {
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
      return true;
    }

    // If this is our first complete attempt with no success
    if (!initialAttemptComplete) {
      initialAttemptComplete = true;

      // If it's clearly not a product page, stop trying aggressively
      if (!productData.isProductPage) {
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

    return false;
  }

  // Function to retry detection with increasing delays
  function retryDetection() {
    if (retryCount >= MAX_RETRIES || productDetected) {
      return;
    }

    retryCount++;
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
      retryDetection();
    }
  }, 700);
}

/**
 * Function to check if current page is a product page
 */
function isProductPage() {
  // 1. Check URL patterns
  const url = window.location.href;
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

  if (productUrlPatterns.some((pattern) => pattern.test(url))) {
    return true;
  }

  // 2. Check for schema.org product markup
  const jsonLdScripts = document.querySelectorAll(
    'script[type="application/ld+json"]'
  );
  for (const script of jsonLdScripts) {
    try {
      const data = JSON.parse(script.textContent);
      if (
        data["@type"] === "Product" ||
        (Array.isArray(data) &&
          data.some((item) => item["@type"] === "Product"))
      ) {
        return true;
      }
    } catch (e) {
      // JSON parsing error, continue to next script
    }
  }

  // 3. Check for product-specific meta tags
  if (
    document.querySelector('meta[property="og:type"][content="product"]') ||
    document.querySelector('meta[property="product:price:amount"]')
  ) {
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

  if (productIndicators.some((selector) => document.querySelector(selector))) {
    return true;
  }

  // 5. Check for typical product page structure
  const hasPrice =
    document.querySelector('[itemprop="price"]') ||
    !!document.body.innerText.match(/[0-9]+[,.][0-9]+\s*(TL|₺|\$|€|£)/);

  const hasProductTitle =
    document.querySelector("h1") && document.querySelectorAll("h1").length < 3; // Usually just one main title

  return hasPrice && hasProductTitle;
}

/**
 * Extracts variant information (colors, sizes, etc.) from the product page
 */
function extractVariantInfo() {
  let variants = {
    colors: [],
    sizes: [],
    otherOptions: [],
  };

  // Helper function to extract option text and selected state
  function extractOptionInfo(element) {
    const text = element.textContent.trim();
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
    }

    // Try to get data-color attribute
    const dataColor =
      element.getAttribute("data-color") ||
      element.getAttribute("data-value") ||
      element.getAttribute("data-option-value");
    if (dataColor) {
      colorValue = dataColor;
    }

    // Check for style attribute with background-color
    const style = element.getAttribute("style");
    if (style && style.includes("background-color")) {
      const match = style.match(/background-color:\s*([^;]+)/i);
      if (match) {
        colorValue = match[1];
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
      }
    }

    return {
      text: text,
      selected: selected,
      value: colorValue,
    };
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

  for (const selector of colorSelectors) {
    const elements = document.querySelectorAll(selector);
    if (elements && elements.length > 0) {
      for (const element of elements) {
        const info = extractOptionInfo(element);
        variants.colors.push(info);
      }
      break;
    }
  }

  // 2. Try to find size options
  const sizeSelectors = [
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

  for (const selector of sizeSelectors) {
    const elements = document.querySelectorAll(selector);
    if (elements && elements.length > 0) {
      for (const element of elements) {
        const info = extractOptionInfo(element);
        variants.sizes.push(info);
      }
      break;
    }
  }

  // 3. Look for select elements that might contain variants
  const selectElements = document.querySelectorAll("select");
  for (const select of selectElements) {
    // Try to determine what type of variant this is
    const labelElement = document.querySelector(`label[for="${select.id}"]`);
    const labelText = labelElement
      ? labelElement.textContent.toLowerCase()
      : "";
    const selectName = select.getAttribute("name")
      ? select.getAttribute("name").toLowerCase()
      : "";

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
    } else if (
      labelText.includes("size") ||
      labelText.includes("beden") ||
      selectName.includes("size") ||
      selectName.includes("beden")
    ) {
      variantType = "sizes";
    }

    // Extract options from this select
    const options = select.querySelectorAll("option");
    for (const option of options) {
      if (!option.value || option.value === "") continue;

      const selected = option.selected;
      const text = option.textContent.trim();

      variants[variantType].push({
        text: text,
        selected: selected,
        value: option.value,
      });
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

  for (const selector of otherVariantSelectors) {
    const elements = document.querySelectorAll(selector);
    if (elements && elements.length > 0) {
      for (const element of elements) {
        const info = extractOptionInfo(element);
        variants.otherOptions.push(info);
      }
    }
  }

  // 5. Try to extract variant info from structured data
  try {
    const jsonLdScripts = document.querySelectorAll(
      'script[type="application/ld+json"]'
    );
    for (const script of jsonLdScripts) {
      const data = JSON.parse(script.textContent);

      // Function to find product data regardless of nesting
      const findVariants = (obj) => {
        if (!obj) return;

        // Check for variants in standard formats
        if (obj.hasOwnProperty("offers") && Array.isArray(obj.offers)) {
          for (const offer of obj.offers) {
            if (
              offer.hasOwnProperty("name") ||
              offer.hasOwnProperty("description")
            ) {
              const name = offer.name || offer.description;
              if (name) {
                // Try to determine if this is a color or size
                if (
                  name.toLowerCase().includes("color") ||
                  name.toLowerCase().includes("colour")
                ) {
                  variants.colors.push({
                    text: name,
                    selected: false,
                    value: null,
                  });
                } else if (name.toLowerCase().includes("size")) {
                  variants.sizes.push({
                    text: name,
                    selected: false,
                    value: null,
                  });
                } else {
                  variants.otherOptions.push({
                    text: name,
                    selected: false,
                    value: null,
                  });
                }
              }
            }
          }
        }

        // Recursively check object properties
        if (typeof obj === "object") {
          for (const key in obj) {
            if (obj.hasOwnProperty(key) && typeof obj[key] === "object") {
              findVariants(obj[key]);
            }
          }
        }
      };

      findVariants(data);
    }
  } catch (e) {
    // JSON parsing error, continue
  }

  return variants;
}

/**
 * Ensures image URLs are absolute
 */
function makeImageUrlAbsolute(imgSrc) {
  if (!imgSrc) return null;

  // Already absolute URL
  if (imgSrc.startsWith("http") || imgSrc.startsWith("https")) {
    return imgSrc;
  }

  // Convert relative URLs to absolute
  if (imgSrc.startsWith("/")) {
    return window.location.origin + imgSrc;
  } else {
    // Handle relative paths without leading slash
    const baseUrl = window.location.href.substring(
      0,
      window.location.href.lastIndexOf("/") + 1
    );
    return baseUrl + imgSrc;
  }
}

/**
 * Main function to extract product information using multiple methods
 */
function extractProductInfo() {
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

  if (!result.isProductPage) {
    return result;
  }

  // Extract variant information using dedicated function
  result.variants = extractVariantInfo();

  // Use multiple methods to extract data, starting with the most reliable

  // Method 1: Structured data (schema.org)
  const structuredData = extractFromStructuredData();
  if (structuredData.success) {
    Object.assign(result, structuredData);
    result.extractionMethod = "structured_data";
    result.success = true;
    return result;
  }

  // Method 2: Meta tags
  const metaTags = extractFromMetaTags();
  if (metaTags.success) {
    Object.assign(result, metaTags);
    result.extractionMethod = "meta_tags";
    result.success = true;
    return result;
  }

  // Method 3: Common selectors
  const commonSelectors = extractFromCommonSelectors();
  if (commonSelectors.success) {
    Object.assign(result, commonSelectors);
    result.extractionMethod = "common_selectors";
    result.success = true;
    return result;
  }

  // Method 4: Content scanning (least reliable, but fallback)
  const contentScan = scanContentForProductInfo();
  if (contentScan.success) {
    Object.assign(result, contentScan);
    result.extractionMethod = "content_scan";
    result.success = true;
    return result;
  }

  return result;
}

/**
 * Extract product info from structured data (JSON-LD)
 */
function extractFromStructuredData() {
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
  for (const script of jsonLdScripts) {
    try {
      const data = JSON.parse(script.textContent);

      // Function to find product data regardless of nesting
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
          if (typeof product.image === "string") {
            result.imageUrl = makeImageUrlAbsolute(product.image);
          } else if (Array.isArray(product.image) && product.image.length > 0) {
            const imgUrl = product.image[0].url || product.image[0];
            result.imageUrl = makeImageUrlAbsolute(imgUrl);
          } else if (product.image.url) {
            result.imageUrl = makeImageUrlAbsolute(product.image.url);
          }
        }

        // Handle offers/pricing
        if (product.offers) {
          let offer = product.offers;

          if (Array.isArray(offer)) {
            offer = offer[0]; // Take the first offer
          }

          if (offer) {
            result.price = offer.price || offer.lowPrice || null;
            result.currency = offer.priceCurrency || null;
            result.availability = offer.availability || null;

            // Check for original price
            if (offer.highPrice && offer.highPrice > offer.price) {
              result.originalPrice = offer.highPrice;
            }
          }
        }

        if (result.title && result.price) {
          result.success = true;
          return result;
        }
      }
    } catch (e) {
      // JSON parsing error, continue to next script
    }
  }

  return result;
}

/**
 * Extract product info from meta tags
 */
function extractFromMetaTags() {
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
  if (titleMeta) {
    result.title = titleMeta.getAttribute("content");
  }

  // Product price
  const priceMeta = document.querySelector(
    'meta[property="product:price:amount"], meta[property="og:price:amount"]'
  );
  if (priceMeta) {
    const price = priceMeta.getAttribute("content");
    if (price && !isNaN(parseFloat(price))) {
      result.price = price;
    }
  }

  // Currency
  const currencyMeta = document.querySelector(
    'meta[property="product:price:currency"], meta[property="og:price:currency"]'
  );
  if (currencyMeta) {
    result.currency = currencyMeta.getAttribute("content");
  }

  // Product image
  const imageMeta = document.querySelector(
    'meta[property="og:image"], meta[name="twitter:image"]'
  );
  if (imageMeta) {
    result.imageUrl = makeImageUrlAbsolute(imageMeta.getAttribute("content"));
  }

  // Product description
  const descMeta = document.querySelector(
    'meta[property="og:description"], meta[name="twitter:description"], meta[name="description"]'
  );
  if (descMeta) {
    result.description = descMeta.getAttribute("content");
  }

  // Brand
  const brandMeta = document.querySelector(
    'meta[property="product:brand"], meta[property="og:brand"]'
  );
  if (brandMeta) {
    result.brand = brandMeta.getAttribute("content");
  }

  // Check if we have the minimum required info
  if (result.title && result.price) {
    result.success = true;
  }

  return result;
}

/**
 * Extract product info using common DOM selectors
 */
function extractFromCommonSelectors() {
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
    if (element && element.textContent.trim()) {
      result.title = element.textContent.trim();
      break;
    }
  }

  // Try to find price
  for (const selector of priceSelectors) {
    const elements = document.querySelectorAll(selector);
    for (const element of elements) {
      if (element && element.textContent.trim()) {
        const text = element.textContent.trim();
        const match = text.match(/([0-9]+[.,][0-9]+)/);
        if (match) {
          // Extract the price and try to determine currency
          let price = match[1].replace(/\./g, "").replace(",", ".");
          result.price = price;

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

          break;
        }
      }
    }
    if (result.price) break;
  }

  // Try to find original price (for discounted items)
  for (const selector of oldPriceSelectors) {
    const elements = document.querySelectorAll(selector);
    for (const element of elements) {
      if (element && element.textContent.trim()) {
        const text = element.textContent.trim();
        const match = text.match(/([0-9]+[.,][0-9]+)/);
        if (match) {
          // Extract the original price
          result.originalPrice = match[1].replace(/\./g, "").replace(",", ".");
          break;
        }
      }
    }
    if (result.originalPrice) break;
  }

  // Try to find image
  for (const selector of imageSelectors) {
    const element = document.querySelector(selector);
    if (
      element &&
      (element.getAttribute("src") || element.getAttribute("data-src"))
    ) {
      let src = element.getAttribute("src") || element.getAttribute("data-src");
      result.imageUrl = makeImageUrlAbsolute(src);
      break;
    }
  }

  // Try to find description
  for (const selector of descriptionSelectors) {
    const element = document.querySelector(selector);
    if (element && element.textContent.trim()) {
      result.description = element.textContent.trim();
      break;
    }
  }

  // Try to find SKU
  for (const selector of skuSelectors) {
    const element = document.querySelector(selector);
    if (element && element.textContent.trim()) {
      result.sku = element.textContent.trim();
      break;
    }
  }

  // Try to find availability
  for (const selector of availabilitySelectors) {
    const element = document.querySelector(selector);
    if (element && element.textContent.trim()) {
      result.availability = element.textContent.trim();
      break;
    }
  }

  // Try to find brand
  for (const selector of brandSelectors) {
    const element = document.querySelector(selector);
    if (element && element.textContent.trim()) {
      result.brand = element.textContent.trim();
      break;
    }
  }

  // Check if we have the minimum required info
  if (result.title && result.price) {
    result.success = true;
  }

  return result;
}

/**
 * Last resort method: scan the document content for likely product info
 */
function scanContentForProductInfo() {
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
  if (h1 && h1.textContent.trim()) {
    result.title = h1.textContent.trim();
  } else {
    // Fallback to title tag
    const titleTag = document.querySelector("title");
    if (titleTag && titleTag.textContent.trim()) {
      result.title = titleTag.textContent.trim();
    }
  }

  // Scan for price patterns in text nodes
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

  // Try to find images that might be product images
  const largeImages = Array.from(document.querySelectorAll("img"))
    .filter((img) => {
      const rect = img.getBoundingClientRect();
      return rect.width > 200 && rect.height > 200;
    })
    .map((img) => img.src || img.getAttribute("data-src"))
    .filter((src) => src)
    .map((src) => makeImageUrlAbsolute(src));

  if (largeImages.length > 0) {
    result.imageUrl = largeImages[0];
  }

  // Select most likely price (closest to product title or largest on page)
  if (priceMatches.length > 0) {
    // Default to first match
    let bestMatch = priceMatches[0];

    if (result.title) {
      // Try to find price closest to title
      const titleElement = document.querySelector("h1");
      if (titleElement) {
        const titleRect = titleElement.getBoundingClientRect();
        let closestDistance = Infinity;

        for (const match of priceMatches) {
          try {
            const rect = match.element.getBoundingClientRect();
            const distance = Math.sqrt(
              Math.pow(rect.top - titleRect.bottom, 2) +
                Math.pow(rect.left - titleRect.left, 2)
            );

            if (distance < closestDistance) {
              closestDistance = distance;
              bestMatch = match;
            }
          } catch (e) {
            // If getBoundingClientRect fails, continue
          }
        }
      }
    }

    result.price = bestMatch.price.replace(/\./g, "").replace(",", ".");
    result.currency = bestMatch.currency;

    // Try to find original price near the current price
    if (bestMatch.element) {
      const nearbyText = bestMatch.element.innerText || "";
      const oldPriceMatch = nearbyText.match(/([0-9]+[.,][0-9]+)/g);
      if (oldPriceMatch && oldPriceMatch.length > 1) {
        // Find a price different from the current price
        for (const price of oldPriceMatch) {
          const cleanPrice = price.replace(/\./g, "").replace(",", ".");
          if (cleanPrice !== result.price) {
            result.originalPrice = cleanPrice;
            break;
          }
        }
      }
    }
  }

  // Check if we have the minimum required info
  if (result.title && result.price) {
    result.success = true;
  }

  return result;
}
