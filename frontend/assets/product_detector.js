/**
 * Product Detector Script for E-commerce Websites
 * This script detects product information from supported e-commerce websites
 * and sends it back to the Flutter app via FlutterChannel.
 */

// Configuration
const CONFIG = {
  initialDelay: 800, // Initial detection delay after page load
  maxRetries: 3, // Maximum number of retry attempts
  retryDelay: 1000, // Delay between retries in ms
  debug: true, // Enable console logs for debugging
};

// Simple logging utility
function log(message, data = null) {
  if (CONFIG.debug) {
    if (data) {
      console.log(`[ProductDetector] ${message}`, data);
    } else {
      console.log(`[ProductDetector] ${message}`);
    }
  }
}

// ==================== SITE DETECTION ====================

// Determine which website we're currently on
function detectSite() {
  const domain = window.location.hostname;

  log(`Checking domain: ${domain}`);

  // Add supported sites here - starting with Gucci
  if (domain.includes("gucci.com")) return "gucci";

  // Future sites will be added here
  // if (domain.includes('zara.com')) return 'zara';
  // if (domain.includes('cartier.com')) return 'cartier';
  // etc.

  return null; // Unknown site
}

// Check if the current page is a product page
function isProductPage() {
  const site = detectSite();
  const url = window.location.href;

  if (!site) return false;

  log(`Checking if product page for site: ${site} - URL: ${url}`);

  switch (site) {
    case "gucci":
      return (
        url.includes("/p/") ||
        url.endsWith(".pd") ||
        !!document.querySelector(".pdp__info") ||
        !!document.querySelector(".product-info") ||
        !!document.querySelector('[data-ctl-name="pdp-page"]') ||
        document
          .querySelector('script[type="application/ld+json"]')
          ?.textContent.includes('"@type":"Product"')
      );

    // Add more site patterns here
    // case 'zara':
    //   return url.includes('/product/') || !!document.querySelector('.product-detail');

    default:
      return false;
  }
}

// ==================== UTILITY FUNCTIONS ====================

// Format price string to numeric value
function formatPrice(priceStr) {
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
}

// Detect currency from price string
function detectCurrency(priceStr) {
  if (!priceStr) return null;

  if (priceStr.includes("$") || priceStr.includes("USD")) return "USD";
  if (priceStr.includes("€") || priceStr.includes("EUR")) return "EUR";
  if (priceStr.includes("£") || priceStr.includes("GBP")) return "GBP";
  if (priceStr.includes("TL") || priceStr.includes("₺")) return "TRY";

  // Default to USD if we can't detect
  return "USD";
}

// Make image URLs absolute
function makeUrlAbsolute(imgSrc) {
  if (!imgSrc) return null;

  // Already absolute URL
  if (imgSrc.startsWith("http")) return imgSrc;

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

// ==================== MAIN EXTRACTION FUNCTIONS ====================

// Extract product information based on the detected site
function extractProductInfo() {
  const site = detectSite();
  const url = window.location.href;

  if (!site) {
    log("Unknown site, cannot extract product info");
    return {
      isProductPage: false,
      success: false,
      url: url,
    };
  }

  // Check if product page
  const productPage = isProductPage();
  log(`Product page check: ${productPage ? "Yes" : "No"} for site: ${site}`);

  if (!productPage) {
    return {
      isProductPage: false,
      success: false,
      url: url,
    };
  }

  // Use the appropriate extractor for the detected site
  switch (site) {
    case "gucci":
      return extractGucciProduct();

    // Future sites will be added here
    // case 'zara':
    //   return extractZaraProduct();

    default:
      return {
        isProductPage: true,
        success: false,
        url: url,
        extractionMethod: "unsupported_site",
      };
  }
}

// ==================== SITE-SPECIFIC EXTRACTORS ====================

// Extract product info for Gucci website
function extractGucciProduct() {
  log("Extracting Gucci product info");

  try {
    // Base result structure
    const result = {
      isProductPage: true,
      url: window.location.href,
      extractionMethod: "gucci",
      success: false,
      variants: {
        colors: [],
        sizes: [],
        otherOptions: [],
      },
    };

    // 1. Try extracting from structured data first (most reliable)
    const jsonLdData = extractGucciStructuredData();
    if (jsonLdData && jsonLdData.success) {
      log("Successfully extracted Gucci product from JSON-LD", jsonLdData);
      return { ...result, ...jsonLdData, success: true };
    }

    // 2. Try extracting from DOM
    const domData = extractGucciDom();
    if (domData && domData.success) {
      log("Successfully extracted Gucci product from DOM", domData);
      return { ...result, ...domData, success: true };
    }

    // 3. Fall back to basic extraction
    const basicData = extractGucciBasic();
    if (basicData && basicData.success) {
      log("Successfully extracted Gucci product using basic method", basicData);
      return { ...result, ...basicData, success: true };
    }

    log("Failed to extract Gucci product info using all methods");
    return result;
  } catch (e) {
    log("Error extracting Gucci product:", e);
    return {
      isProductPage: true,
      url: window.location.href,
      extractionMethod: "gucci_error",
      success: false,
      error: e.message,
    };
  }
}

// Extract Gucci product from structured data (JSON-LD)
function extractGucciStructuredData() {
  log("Trying to extract from Gucci JSON-LD data");

  try {
    const scripts = document.querySelectorAll(
      'script[type="application/ld+json"]'
    );
    if (!scripts.length) return null;

    let productData = null;

    // Search through JSON-LD scripts for product data
    for (const script of scripts) {
      try {
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
          break;
        }
      } catch (e) {
        log("Error parsing JSON-LD script:", e);
      }
    }

    if (!productData) return null;

    log("Found product in JSON-LD", productData);

    // Extract information
    const result = {
      title: productData.name || null,
      brand: productData.brand?.name || "Gucci",
      description: productData.description || null,
      sku: productData.sku || productData.mpn || null,
      variants: {
        colors: [],
        sizes: [],
        otherOptions: [],
      },
      success: false,
    };

    // Extract price
    if (productData.offers) {
      let offer = productData.offers;

      if (Array.isArray(offer)) {
        offer = offer[0]; // Use first offer
      }

      if (offer) {
        result.price = formatPrice(offer.price?.toString());
        result.currency =
          offer.priceCurrency || detectCurrency(offer.price?.toString());

        // Check for original price (sale)
        if (
          offer.highPrice &&
          offer.lowPrice &&
          offer.highPrice > offer.lowPrice
        ) {
          result.originalPrice = formatPrice(offer.highPrice.toString());
        }

        // Availability
        if (offer.availability) {
          const avail = offer.availability;
          if (avail.includes("InStock")) {
            result.availability = "In Stock";
          } else if (avail.includes("OutOfStock")) {
            result.availability = "Out of Stock";
          } else if (avail.includes("LimitedAvailability")) {
            result.availability = "Limited Availability";
          } else if (avail.includes("PreOrder")) {
            result.availability = "Pre-Order";
          }
        }
      }
    }

    // Extract image
    if (productData.image) {
      if (typeof productData.image === "string") {
        result.imageUrl = makeUrlAbsolute(productData.image);
      } else if (
        Array.isArray(productData.image) &&
        productData.image.length > 0
      ) {
        const imgUrl = productData.image[0].url || productData.image[0];
        result.imageUrl = makeUrlAbsolute(imgUrl);
      } else if (productData.image.url) {
        result.imageUrl = makeUrlAbsolute(productData.image.url);
      }
    }

    // Check if we have the minimum needed information
    result.success = !!(result.title && result.price);

    return result;
  } catch (e) {
    log("Error extracting from structured data:", e);
    return null;
  }
}

// Extract Gucci product from DOM elements
function extractGucciDom() {
  log("Trying to extract from Gucci DOM elements");

  try {
    const result = {
      variants: {
        colors: [],
        sizes: [],
        otherOptions: [],
      },
      success: false,
    };

    // Title - try various selectors
    const titleElement =
      document.querySelector(".pdp__info-title") ||
      document.querySelector(".product-detail__title") ||
      document.querySelector('[data-ctl-name="pdp-title"]') ||
      document.querySelector("h1");

    if (titleElement) {
      result.title = titleElement.textContent.trim();
      log("Found title:", result.title);
    }

    // Price - try various selectors
    const priceElement =
      document.querySelector(".pdp__info-price") ||
      document.querySelector(".product-detail__price") ||
      document.querySelector('[data-ctl-name="pdp-price"]') ||
      document.querySelector('[itemprop="price"]');

    if (priceElement) {
      const priceText = priceElement.textContent.trim();
      result.price = formatPrice(priceText);
      result.currency = detectCurrency(priceText);
      log("Found price:", result.price, result.currency);
    }

    // Original price (for sales)
    const originalPriceElement =
      document.querySelector(".pdp__info-original-price") ||
      document.querySelector(".product-detail__original-price") ||
      document.querySelector(".original-price");

    if (originalPriceElement) {
      const originalPriceText = originalPriceElement.textContent.trim();
      result.originalPrice = formatPrice(originalPriceText);
      log("Found original price:", result.originalPrice);
    }

    // Image - try various selectors
    const imageElement =
      document.querySelector(".pdp-carousel__image img") ||
      document.querySelector(".product-detail__image img") ||
      document.querySelector('[data-ctl-name="pdp-gallery"] img') ||
      document.querySelector(".product-image img");

    if (imageElement) {
      result.imageUrl = makeUrlAbsolute(
        imageElement.src || imageElement.getAttribute("data-src")
      );
      log("Found image:", result.imageUrl);
    }

    // Description - try various selectors
    const descElement =
      document.querySelector(".pdp__info-description") ||
      document.querySelector(".product-detail__description") ||
      document.querySelector('[data-ctl-name="pdp-description"]') ||
      document.querySelector('[itemprop="description"]');

    if (descElement) {
      result.description = descElement.textContent.trim();
      log("Found description");
    }

    // Brand - for Gucci website, this is "Gucci"
    result.brand = "Gucci";

    // Extract sizes
    extractGucciSizes(result);

    // Extract colors
    extractGucciColors(result);

    // Check if we have the minimum needed information
    result.success = !!(result.title && result.price);

    return result;
  } catch (e) {
    log("Error extracting from DOM:", e);
    return null;
  }
}

// Extract sizes from Gucci product page
function extractGucciSizes(result) {
  try {
    // Find size selector
    const sizeSelector =
      document.querySelector(".pdp-size-selector") ||
      document.querySelector(".product-detail__size-selector") ||
      document.querySelector('[data-ctl-name="pdp-size-selector"]');

    if (!sizeSelector) {
      log("No size selector found");
      return;
    }

    log("Found size selector");

    // Find selected size
    const selectedSize =
      sizeSelector.querySelector(".selected") ||
      sizeSelector.querySelector('[aria-selected="true"]') ||
      sizeSelector.querySelector(".active");

    // Get all size options
    const sizeOptions = sizeSelector.querySelectorAll(
      "button, .size-option, li"
    );

    if (sizeOptions.length === 0) {
      log("No size options found");
      return;
    }

    log(`Found ${sizeOptions.length} size options`);

    // Process each size option
    for (const option of sizeOptions) {
      const text = option.textContent.trim();

      // Skip empty or placeholder options
      if (!text || text === "Select Size") continue;

      const isSelected =
        option === selectedSize ||
        option.classList.contains("selected") ||
        option.getAttribute("aria-selected") === "true";

      const value = option.value || option.getAttribute("data-value") || text;

      result.variants.sizes.push({
        text: text,
        selected: isSelected,
        value: value,
      });

      log(`Added size: ${text}, selected: ${isSelected}`);
    }

    // If no sizes found directly, try script data
    if (result.variants.sizes.length === 0) {
      log("Looking for size data in scripts");

      const scripts = document.querySelectorAll("script:not([src])");
      for (const script of scripts) {
        if (
          script.textContent.includes("pdpSizes") ||
          script.textContent.includes("sizes") ||
          script.textContent.includes("sizeChart")
        ) {
          // Try to extract size data with regex
          const sizeMatch =
            script.textContent.match(/pdpSizes\s*=\s*(\[.*?\])/s) ||
            script.textContent.match(/sizes\s*=\s*(\[.*?\])/s) ||
            script.textContent.match(/sizeData\s*=\s*(\[.*?\])/s);

          if (sizeMatch && sizeMatch[1]) {
            try {
              // Convert to valid JSON
              const jsonStr = sizeMatch[1]
                .replace(/'/g, '"')
                .replace(/(\w+):/g, '"$1":')
                .replace(/,\s*}/g, "}")
                .replace(/,\s*\]/g, "]");

              const sizeData = JSON.parse(jsonStr);

              if (Array.isArray(sizeData) && sizeData.length > 0) {
                log(`Found ${sizeData.length} sizes in script data`);

                for (const size of sizeData) {
                  if (typeof size === "string") {
                    result.variants.sizes.push({
                      text: size,
                      selected: false,
                      value: size,
                    });
                  } else if (typeof size === "object" && size !== null) {
                    result.variants.sizes.push({
                      text:
                        size.label ||
                        size.name ||
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
              log("Error parsing size data:", e);
            }
          }
        }
      }
    }
  } catch (e) {
    log("Error extracting sizes:", e);
  }
}

// Extract colors from Gucci product page
function extractGucciColors(result) {
  try {
    // Find color selector
    const colorSelector =
      document.querySelector(".pdp-color-selector") ||
      document.querySelector(".product-detail__color-selector") ||
      document.querySelector('[data-ctl-name="pdp-color-selector"]');

    if (!colorSelector) {
      log("No color selector found");
      return;
    }

    log("Found color selector");

    // Find selected color
    const selectedColor =
      colorSelector.querySelector(".selected") ||
      colorSelector.querySelector('[aria-selected="true"]') ||
      colorSelector.querySelector(".active");

    // Get all color options
    const colorOptions = colorSelector.querySelectorAll(
      "button, .color-option, li"
    );

    if (colorOptions.length === 0) {
      log("No color options found");
      return;
    }

    log(`Found ${colorOptions.length} color options`);

    // Process each color option
    for (const option of colorOptions) {
      // Skip empty options
      if (!option) continue;

      const isSelected =
        option === selectedColor ||
        option.classList.contains("selected") ||
        option.getAttribute("aria-selected") === "true";

      // Try to get color name/text
      let colorText =
        option.getAttribute("title") || option.getAttribute("aria-label") || "";
      if (!colorText) {
        colorText = option.textContent.trim();
      }

      // Skip empty or placeholder options
      if (!colorText || colorText === "Select Color") continue;

      // Try to get color value (could be a color code or image URL)
      let colorValue =
        option.value ||
        option.getAttribute("data-color") ||
        option.getAttribute("data-value");

      // If no explicit value, try to get background color or image
      if (!colorValue) {
        const computedStyle = window.getComputedStyle(option);
        const bgColor = computedStyle.backgroundColor;

        if (
          bgColor &&
          bgColor !== "transparent" &&
          bgColor !== "rgba(0, 0, 0, 0)"
        ) {
          colorValue = bgColor;
        } else {
          // Check for image
          const img = option.querySelector("img");
          if (img) {
            colorValue = makeUrlAbsolute(img.src);
          }
        }
      }

      result.variants.colors.push({
        text: colorText,
        selected: isSelected,
        value: colorValue || colorText,
      });

      log(`Added color: ${colorText}, selected: ${isSelected}`);
    }
  } catch (e) {
    log("Error extracting colors:", e);
  }
}

// Extract Gucci product using basic method (fallback)
function extractGucciBasic() {
  log("Trying basic extraction for Gucci product");

  try {
    const result = {
      variants: {
        colors: [],
        sizes: [],
        otherOptions: [],
      },
      success: false,
    };

    // Find any heading that might be a product title
    const h1Elements = document.querySelectorAll("h1");
    if (h1Elements.length > 0) {
      result.title = h1Elements[0].textContent.trim();
      log("Found title from h1:", result.title);
    }

    // Find any price by looking for currency symbols
    const priceRegex = /([0-9.,]+)\s*(?:€|\$|£|TL|₺)/;
    const textElements = document.querySelectorAll("p, span, div");

    for (const element of textElements) {
      const text = element.textContent.trim();
      const match = text.match(priceRegex);

      if (match) {
        log("Found price text:", text);
        result.price = formatPrice(match[0]);
        result.currency = detectCurrency(match[0]);
        break;
      }
    }

    // Find main product image
    const images = document.querySelectorAll("img");
    for (const img of images) {
      // Look for large images that might be product images
      const rect = img.getBoundingClientRect();
      if (rect.width > 200 && rect.height > 200) {
        result.imageUrl = makeUrlAbsolute(
          img.src || img.getAttribute("data-src")
        );
        log("Found potential product image:", result.imageUrl);
        break;
      }
    }

    // Set brand to Gucci
    result.brand = "Gucci";

    // Check if we have the minimum needed information
    result.success = !!(result.title && result.price);

    return result;
  } catch (e) {
    log("Error during basic extraction:", e);
    return null;
  }
}

// ==================== MAIN EXECUTION LOGIC ====================

// Main function to detect and report product info
function detectAndReportProduct(retryCount = 0) {
  log(`Running product detection (attempt: ${retryCount + 1})`);

  try {
    // Check if FlutterChannel exists
    if (!window.FlutterChannel) {
      log("FlutterChannel not available, cannot report data");

      // Retry if under max retries
      if (retryCount < CONFIG.maxRetries) {
        setTimeout(() => {
          detectAndReportProduct(retryCount + 1);
        }, CONFIG.retryDelay);
      }
      return;
    }

    // Extract product info
    const productInfo = extractProductInfo();

    // Report back to Flutter
    log("Sending product info to Flutter:", productInfo);
    window.FlutterChannel.postMessage(JSON.stringify(productInfo));

    // Retry if needed
    if (
      (!productInfo.isProductPage || !productInfo.success) &&
      retryCount < CONFIG.maxRetries
    ) {
      log(`Scheduling retry ${retryCount + 1} in ${CONFIG.retryDelay}ms`);
      setTimeout(() => {
        detectAndReportProduct(retryCount + 1);
      }, CONFIG.retryDelay);
    }
  } catch (e) {
    log("Error in product detection:", e);

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

// ==================== INITIALIZATION & OBSERVERS ====================

// Start detection on page load
window.addEventListener("load", () => {
  log("Page loaded, initializing product detector");
  setTimeout(() => {
    detectAndReportProduct();
  }, CONFIG.initialDelay);
});

// Start immediately (don't wait for full load)
log("Product detector script loaded, starting detection");
setTimeout(() => {
  detectAndReportProduct();
}, 300);

// Watch for DOM changes (for single-page apps)
const observer = new MutationObserver(() => {
  log("DOM changes detected, checking for product info");
  detectAndReportProduct();
});

// Start observing the DOM
observer.observe(document.body, {
  childList: true,
  subtree: true,
  attributes: false,
  characterData: false,
});
