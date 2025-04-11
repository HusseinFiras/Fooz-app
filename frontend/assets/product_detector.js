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

  // Debug helper to log common product page selectors
  function logSelectors() {
    const selectors = [
      { name: ".pdp__info", found: !!document.querySelector(".pdp__info") },
      {
        name: ".product-info",
        found: !!document.querySelector(".product-info"),
      },
      {
        name: '[data-ctl-name="pdp-page"]',
        found: !!document.querySelector('[data-ctl-name="pdp-page"]'),
      },
      {
        name: ".product-detail",
        found: !!document.querySelector(".product-detail"),
      },
      {
        name: ".product-details",
        found: !!document.querySelector(".product-details"),
      },
      {
        name: ".product__details",
        found: !!document.querySelector(".product__details"),
      },
      {
        name: ".product-description",
        found: !!document.querySelector(".product-description"),
      },
      { name: ".add-to-cart", found: !!document.querySelector(".add-to-cart") },
      {
        name: "product-name",
        found: !!document.querySelector(".product-name"),
      },
      {
        name: "h1 element",
        found: !!document.querySelector("h1"),
        text: document.querySelector("h1")?.textContent.trim(),
      },
      // Specific selector from your HTML
      {
        name: "Size dropdown",
        found: !!document.querySelector(
          "#product-detail-add-to-shopping-bag-form"
        ),
      },
      {
        name: "select2-dropdown",
        found: !!document.querySelector(".select2-dropdown"),
      },
      { name: "slick-track", found: !!document.querySelector(".slick-track") },
    ];

    log("Checking common product page selectors:", selectors);

    // Check for product structured data
    const hasStructuredData = document
      .querySelector('script[type="application/ld+json"]')
      ?.textContent.includes('"@type":"Product"');
    log("Has product structured data:", hasStructuredData);

    return selectors;
  }

  switch (site) {
    case "gucci":
      // Check URL patterns for Gucci
      const gucciUrlCheck =
        url.includes("/p/") ||
        url.includes("/pr/") || // Added this pattern which appears in your logs
        url.endsWith(".pd") ||
        url.includes("-p-"); // Product ID pattern

      // Check DOM selectors for Gucci - including the specific ones from your HTML
      const gucciDomCheck =
        !!document.querySelector(".pdp__info") ||
        !!document.querySelector(".product-info") ||
        !!document.querySelector('[data-ctl-name="pdp-page"]') ||
        !!document.querySelector(".product__name") ||
        !!document.querySelector(".product-hero") ||
        !!document.querySelector('[itemprop="price"]') ||
        !!document.querySelector("#product-detail-add-to-shopping-bag-form") || // From your HTML
        !!document.querySelector(".size-dropdown") || // From your HTML
        !!document.querySelector(".select2-dropdown") || // From your HTML
        !!document.querySelector(".select2-results__options") || // From your HTML
        !!document.querySelector(".slick-track"); // From your HTML

      // Check structured data for Gucci
      const gucciStructuredCheck = document
        .querySelector('script[type="application/ld+json"]')
        ?.textContent.includes('"@type":"Product"');

      // Log debugging info
      log("Gucci product page checks:", {
        urlCheck: gucciUrlCheck,
        domCheck: gucciDomCheck,
        structuredCheck: gucciStructuredCheck,
      });

      // If still not detected, log all selectors for debugging
      if (!gucciUrlCheck && !gucciDomCheck && !gucciStructuredCheck) {
        logSelectors();
      }

      return gucciUrlCheck || gucciDomCheck || gucciStructuredCheck;

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

        // Try to extract sizes from nested offers (some sites use this pattern)
        if (
          Array.isArray(productData.offers) &&
          productData.offers.length > 1
        ) {
          log("Multiple offers found, checking for size variants");

          const sizeSet = new Set();

          for (const subOffer of productData.offers) {
            // Look for size information in different locations
            const size =
              subOffer.size ||
              subOffer.name?.match(/size:?\s*(\S+)/i)?.[1] ||
              subOffer.description?.match(/size:?\s*(\S+)/i)?.[1];

            if (size && !sizeSet.has(size)) {
              sizeSet.add(size);
              result.variants.sizes.push({
                text: size,
                selected: false,
                value: size,
              });

              log(`Added size from JSON-LD offer: ${size}`);
            }
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

    // Extract color variants - some sites include this in the structured data
    if (productData.color) {
      // Handle different formats of the color property
      if (typeof productData.color === "string") {
        result.variants.colors.push({
          text: productData.color,
          selected: true, // If it's in the main product, it's likely selected
          value: productData.color,
        });

        log(`Added color from JSON-LD: ${productData.color}`);
      } else if (Array.isArray(productData.color)) {
        for (const color of productData.color) {
          if (typeof color === "string") {
            result.variants.colors.push({
              text: color,
              selected: false,
              value: color,
            });

            log(`Added color from JSON-LD array: ${color}`);
          }
        }
      }
    }

    // Extract any available variants
    if (productData.offers && productData.offers.itemOffered) {
      const variants = Array.isArray(productData.offers.itemOffered)
        ? productData.offers.itemOffered
        : [productData.offers.itemOffered];

      for (const variant of variants) {
        // Extract color
        if (
          variant.color &&
          !result.variants.colors.some((c) => c.text === variant.color)
        ) {
          result.variants.colors.push({
            text: variant.color,
            selected: false,
            value: variant.color,
          });

          log(`Added color from variant: ${variant.color}`);
        }

        // Extract size
        if (
          variant.size &&
          !result.variants.sizes.some((s) => s.text === variant.size)
        ) {
          result.variants.sizes.push({
            text: variant.size,
            selected: false,
            value: variant.size,
          });

          log(`Added size from variant: ${variant.size}`);
        }
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

    // Log all available H1 elements for debugging Gucci's structure
    const allH1s = document.querySelectorAll("h1");
    log(`Found ${allH1s.length} H1 elements on page`);
    for (let i = 0; i < allH1s.length; i++) {
      log(
        `H1 #${i + 1}: "${allH1s[i].textContent.trim()}" with classes: ${
          allH1s[i].className
        }`
      );
    }

    // Extract product name - try harder to find it when h1 is not present
    let titleElement = document.querySelector("h1");

    // If no h1, try other common product title patterns
    if (
      !titleElement ||
      !titleElement.textContent ||
      titleElement.textContent.trim() === ""
    ) {
      const possibleTitleElements = [
        // Try meta tags first
        document.querySelector('meta[property="og:title"]'),
        document.querySelector('meta[name="twitter:title"]'),
        // Then try common DOM patterns
        document.querySelector(".product-name"),
        document.querySelector(".pdp-title"),
        document.querySelector(".prod-title"),
        document.querySelector(".product-detail-name"),
        document.querySelector('[class*="product"][class*="title"]'),
        document.querySelector('[class*="product"][class*="name"]'),
      ];

      // Find the first element that has text content
      for (const element of possibleTitleElements) {
        if (element) {
          // Meta tags have content attribute
          if (element.tagName === "META") {
            result.title = element.getAttribute("content");
            log("Found title from meta tag:", result.title);
            break;
          } else if (element.textContent && element.textContent.trim() !== "") {
            result.title = element.textContent.trim();
            log("Found title from alternative element:", result.title);
            break;
          }
        }
      }

      // Try to get the title from the page title as last resort
      if (!result.title) {
        const pageTitle = document.title;
        if (pageTitle) {
          // Often page titles follow pattern: "Product Name | Brand Name"
          const titleParts = pageTitle.split("|");
          if (titleParts.length > 1) {
            result.title = titleParts[0].trim();
          } else {
            result.title = pageTitle;
          }
          log("Extracted title from page title:", result.title);
        }
      }
    } else if (titleElement) {
      result.title = titleElement.textContent.trim();
      log("Found title from h1:", result.title);
    }

    // Log all elements with 'price' in their class name
    const priceElements = document.querySelectorAll(
      '[class*="price" i], [class*="Price" i]'
    );
    log(`Found ${priceElements.length} potential price elements`);
    for (let i = 0; i < Math.min(priceElements.length, 5); i++) {
      if (priceElements[i] && priceElements[i].textContent) {
        log(
          `Price element #${i + 1}: "${priceElements[
            i
          ].textContent.trim()}" with classes: ${priceElements[i].className}`
        );
      }
    }

    // Price - try various selectors for current Gucci site
    const priceElement =
      document.querySelector(".product-detail-price") ||
      document.querySelector(".product-price") ||
      document.querySelector(".price-value") ||
      document.querySelector(".product-detail__price") ||
      document.querySelector(".price-current") ||
      document.querySelector(".product-prices") ||
      document.querySelector('[class*="price"]:not([class*="original"])');

    if (priceElement && priceElement.textContent) {
      const priceText = priceElement.textContent.trim();
      result.price = formatPrice(priceText);
      result.currency = detectCurrency(priceText);
      log("Found price:", result.price, result.currency);
    } else {
      // Try finding any text that looks like a price
      const allElements = document.querySelectorAll("p, span, div");
      const priceRegex = /([0-9.,]+)\s*(?:€|\$|£|TL|₺)/;

      for (const element of allElements) {
        if (element && element.textContent) {
          const text = element.textContent.trim();
          const match = text.match(priceRegex);

          if (match) {
            log("Found price text by regex:", text);
            result.price = formatPrice(match[0]);
            result.currency = detectCurrency(match[0]);
            break;
          }
        }
      }
    }

    // Original price (for sales)
    const originalPriceElement =
      document.querySelector(".product-detail-original-price") ||
      document.querySelector(".original-price") ||
      document.querySelector(".price-original") ||
      document.querySelector(".product-detail__original-price") ||
      document.querySelector('[class*="original"][class*="price" i]');

    if (originalPriceElement && originalPriceElement.textContent) {
      const originalPriceText = originalPriceElement.textContent.trim();
      result.originalPrice = formatPrice(originalPriceText);
      log("Found original price:", result.originalPrice);
    }

    // Image - try various selectors
    const imageElements = document.querySelectorAll("img");
    let bestImage = null;
    let largestArea = 0;

    // Find the largest image that's likely to be a product image
    for (const img of imageElements) {
      if (!img) continue;

      const rect = img.getBoundingClientRect();
      const area = rect.width * rect.height;

      if (area > largestArea && rect.width > 100 && rect.height > 100) {
        largestArea = area;
        bestImage = img;
      }
    }

    if (bestImage) {
      result.imageUrl = makeUrlAbsolute(
        bestImage.src || bestImage.getAttribute("data-src")
      );
      log("Found best image:", result.imageUrl);
    } else {
      // Try specific selectors if we couldn't find by size
      const imageElement =
        document.querySelector(".product-detail-image img") ||
        document.querySelector(".gallery-image img") ||
        document.querySelector(".product-image img") ||
        document.querySelector(".pdp-image img") ||
        document.querySelector('[aria-label="Product image"] img');

      if (imageElement) {
        result.imageUrl = makeUrlAbsolute(
          imageElement.src || imageElement.getAttribute("data-src")
        );
        log("Found image by selector:", result.imageUrl);
      }
    }

    // Description - try various selectors
    const descElement =
      document.querySelector(".product-detail-description") ||
      document.querySelector(".product-description") ||
      document.querySelector(".description") ||
      document.querySelector(".pdp-description") ||
      document.querySelector(".product-detail__description");

    if (descElement && descElement.textContent) {
      result.description = descElement.textContent.trim();
      log("Found description");
    }

    // Brand - for Gucci website, this is "Gucci"
    result.brand = "Gucci";

    // Extract sizes
    result.variants = {
      colors: [],
      sizes: [],
      otherOptions: [],
    };

    // Call size and color extractors with safety checks
    try {
      extractGucciSizes(result);
    } catch (e) {
      log("Error in size extraction:", e);
    }

    try {
      extractGucciColors(result);
    } catch (e) {
      log("Error in color extraction:", e);
    }

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
    log("Extracting Gucci sizes");

    // DIRECT SELECTOR FROM USER: Try the exact CSS selector provided
    try {
      const directSizeSelector =
        "#product-detail-add-to-shopping-bag-form > div > div.sizes > div.size-dropdown > div > div > span:nth-child(3) > span";
      const directSizes = document.querySelectorAll(directSizeSelector);

      if (directSizes && directSizes.length > 0) {
        log(
          `Found ${directSizes.length} size options using direct CSS selector`
        );

        for (const option of directSizes) {
          if (!option) continue;
          if (!option.textContent) continue;

          const text = option.textContent.trim();
          if (!text || text.toLowerCase().includes("select size")) continue;

          result.variants.sizes.push({
            text: text,
            selected: false, // Can't determine selected state from this selector
            value: text,
          });

          log(`Added size from direct selector: ${text}`);
        }

        if (result.variants.sizes.length > 0) {
          return; // Successfully found sizes using direct selector
        }
      }
    } catch (e) {
      log("Error with direct selector:", e);
    }

    // Look for Select2 dropdown which might be shown in a different part of the DOM
    // This is specifically targeting the structure in the provided HTML
    try {
      const select2OptionElements = document.querySelectorAll(
        ".select2-results__option"
      );

      if (select2OptionElements && select2OptionElements.length > 0) {
        log(`Found ${select2OptionElements.length} Select2 option elements`);

        for (const option of select2OptionElements) {
          if (!option) continue;

          // Get the size content within the option
          const sizeSpan = option.querySelector(".custom-select-content-size");
          if (!sizeSpan || !sizeSpan.textContent) continue;

          const text = sizeSpan.textContent.trim();
          if (!text || text.toLowerCase().includes("select size")) continue;

          const isSelected = option.classList.contains(
            "select2-results__option--highlighted"
          );

          result.variants.sizes.push({
            text: text,
            selected: isSelected,
            value: text,
          });

          log(
            `Added size from Select2 results: ${text}, selected: ${isSelected}`
          );
        }

        if (result.variants.sizes.length > 0) {
          return; // Successfully found sizes in Select2
        }
      }
    } catch (e) {
      log("Error with Select2 extraction:", e);
    }

    // Look for size dropdown content directly
    try {
      const customSizeElements = document.querySelectorAll(
        ".custom-select-content-size"
      );

      if (customSizeElements && customSizeElements.length > 0) {
        log(`Found ${customSizeElements.length} custom size content elements`);

        for (const element of customSizeElements) {
          if (!element || !element.textContent) continue;

          const text = element.textContent.trim();
          if (!text || text.toLowerCase().includes("select size")) continue;

          result.variants.sizes.push({
            text: text,
            selected: false, // Can't determine selected state
            value: text,
          });

          log(`Added size directly: ${text}`);
        }

        if (result.variants.sizes.length > 0) {
          return; // Successfully found sizes
        }
      }
    } catch (e) {
      log("Error with custom size content extraction:", e);
    }

    // If Select2 not found, try other size selectors
    const altSizeSelectors = [
      "#product-detail-add-to-shopping-bag-form .size-dropdown .custom-select-size--available",
      ".pdp-size-selector li",
      ".size-selector li",
      ".size-dropdown select option",
      ".size-option",
      // More general selectors
      ".sizes span",
      ".sizes option",
      '[id*="size-selector"] li',
      '[id*="size-selector"] span',
    ];

    for (const selector of altSizeSelectors) {
      try {
        const elements = document.querySelectorAll(selector);
        if (elements && elements.length > 0) {
          log(
            `Found ${elements.length} size options using selector: ${selector}`
          );

          for (const element of elements) {
            if (!element || !element.textContent) continue;

            // Skip "Select size" placeholder
            const text = element.textContent.trim();
            if (!text || text.toLowerCase().includes("select size")) continue;

            const isSelected =
              element.classList.contains("selected") ||
              element.classList.contains("active") ||
              element.closest(".selected") !== null;

            result.variants.sizes.push({
              text: text,
              selected: isSelected,
              value: text,
            });

            log(`Added size: ${text}, selected: ${isSelected}`);
          }

          if (result.variants.sizes.length > 0) {
            return; // Found sizes with this selector
          }
        }
      } catch (e) {
        log(`Error with alternate selector ${selector}:`, e);
      }
    }

    // If still no sizes found, log it
    log("No size options found on page");
  } catch (e) {
    log("Error extracting sizes:", e);
  }
}

// Extract colors from Gucci product page
function extractGucciColors(result) {
  try {
    log("Extracting Gucci colors");

    // Directly extract color info from the HTML you provided
    try {
      // Look specifically for .carousel-slide or .slick-slide elements
      const colorSlides = document.querySelectorAll(
        ".carousel-slide, .slick-slide"
      );

      if (colorSlides && colorSlides.length > 0) {
        log(`Found ${colorSlides.length} potential color slides in carousel`);

        for (const slide of colorSlides) {
          if (!slide) continue;

          // Look for the tooltip content which contains color name
          const tooltipContent = slide.querySelector(
            "[data-gg-tooltip--content]"
          );
          if (!tooltipContent || !tooltipContent.textContent) continue;

          const colorText = tooltipContent.textContent.trim();
          if (!colorText) continue;

          // Check if this is the selected/current slide
          const isSelected =
            slide.classList.contains("slick-current") ||
            slide.classList.contains("slick-active") ||
            slide.classList.contains("selected");

          // Try to get color image URL
          let colorImgUrl = null;
          const img = slide.querySelector("img");
          if (img && img.src) {
            colorImgUrl = makeUrlAbsolute(
              img.src || img.srcset || img.getAttribute("data-src")
            );
          }

          result.variants.colors.push({
            text: colorText,
            selected: isSelected,
            value: colorImgUrl || colorText,
          });

          log(
            `Added color from carousel: ${colorText}, selected: ${isSelected}`
          );
        }

        if (result.variants.colors.length > 0) {
          return; // Successfully found colors in carousel
        }
      }
    } catch (e) {
      log("Error with carousel color extraction:", e);
    }

    // Try to extract color tooltips directly
    try {
      const tooltipContents = document.querySelectorAll(
        "[data-gg-tooltip--content]"
      );

      if (tooltipContents && tooltipContents.length > 0) {
        log(`Found ${tooltipContents.length} color tooltip contents`);

        for (const tooltip of tooltipContents) {
          if (!tooltip || !tooltip.textContent) continue;

          const colorText = tooltip.textContent.trim();
          if (!colorText) continue;

          // Try to find the image associated with this tooltip
          let colorImgUrl = null;
          const parentSlide = tooltip.closest(".carousel-slide, .slick-slide");
          if (parentSlide) {
            const img = parentSlide.querySelector("img");
            if (img && img.src) {
              colorImgUrl = makeUrlAbsolute(
                img.src || img.srcset || img.getAttribute("data-src")
              );
            }
          }

          result.variants.colors.push({
            text: colorText,
            selected: parentSlide
              ? parentSlide.classList.contains("slick-current")
              : false,
            value: colorImgUrl || colorText,
          });

          log(`Added color from tooltip: ${colorText}`);
        }

        if (result.variants.colors.length > 0) {
          return; // Successfully found colors in tooltips
        }
      }
    } catch (e) {
      log("Error with tooltip color extraction:", e);
    }

    // If carousel not found, try other color selectors
    const altColorSelectors = [
      ".product-colors .color-swatch",
      ".pdp-color-selector [data-color]",
      ".color-option",
      ".color-selector li",
      ".color-swatches .swatch",
    ];

    for (const selector of altColorSelectors) {
      try {
        const elements = document.querySelectorAll(selector);
        if (elements && elements.length > 0) {
          log(
            `Found ${elements.length} color options using selector: ${selector}`
          );

          for (const element of elements) {
            if (!element) continue;

            // Try to get color name from various attributes
            let colorText =
              element.getAttribute("title") ||
              element.getAttribute("aria-label") ||
              element.getAttribute("data-color-name");

            // Only try textContent if we haven't found the color name in attributes
            if (!colorText && element.textContent) {
              colorText = element.textContent.trim();
            }

            if (!colorText) continue;

            const isSelected =
              element.classList.contains("selected") ||
              element.classList.contains("active") ||
              element.classList.contains("current");

            // Try to get color value (could be color code or image)
            let colorValue =
              element.getAttribute("data-color") ||
              element.getAttribute("data-color-value");

            // If no explicit value, try background color or image
            if (!colorValue) {
              const img = element.querySelector("img");
              if (img && img.src) {
                colorValue = makeUrlAbsolute(img.src || img.srcset);
              } else {
                try {
                  const style = window.getComputedStyle(element);
                  colorValue = style.backgroundColor;
                } catch (e) {
                  // Ignore style errors
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

          if (result.variants.colors.length > 0) {
            return; // Found colors with this selector
          }
        }
      } catch (e) {
        log(`Error with alternate color selector ${selector}:`, e);
      }
    }

    // Try a more general approach for finding colors - look for elements that might be color indicators
    try {
      const possibleColorTags = [
        "color",
        "colour",
        "shade",
        "finish",
        "hue",
        "dye",
        "tone",
        "tint",
      ];

      for (const tag of possibleColorTags) {
        const elements = document.querySelectorAll(
          `[class*="${tag}" i], [id*="${tag}" i], [data-*="${tag}" i]`
        );

        if (elements && elements.length > 0) {
          log(
            `Found ${elements.length} possible color elements with tag '${tag}'`
          );

          for (const element of elements) {
            if (!element || !element.textContent) continue;

            const text = element.textContent.trim();
            if (!text) continue;

            // Skip elements with too much text (likely not a color)
            if (text.length > 30 || text.includes("\n")) continue;

            result.variants.colors.push({
              text: text,
              selected: false,
              value: text,
            });

            log(`Added possible color from general search: ${text}`);
          }

          if (result.variants.colors.length > 0) {
            return; // Found colors with this general approach
          }
        }
      }
    } catch (e) {
      log("Error with general color search:", e);
    }

    // If still no colors found, log it
    log("No color options found on page");
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

// Direct product finder function - finds any product-like structure on the page
function findAnyProductInfo() {
  log("Emergency product detection - looking for any product-like elements");

  // Check if this page seems to be a product page by URL
  const url = window.location.href;
  const isProbablyProductPage =
    url.includes("/pr/") ||
    url.includes("/p/") ||
    url.includes("-p-") ||
    url.match(/\/[A-Za-z0-9]{6,}$/); // Ends with product code

  log(
    `URL product check: ${
      isProbablyProductPage ? "Likely product page" : "Not sure"
    } - ${url}`
  );

  // Log DOM structure information to help debug
  logPageStructure();

  // Result object to store found info
  const result = {
    isProbablyProductPage,
    foundElements: {},
  };

  // Check for product title (h1 or other heading elements)
  const headings = document.querySelectorAll("h1, h2");
  if (headings.length > 0) {
    result.foundElements.title = {
      element: headings[0].tagName,
      text: headings[0].textContent.trim(),
      classes: headings[0].className,
    };
  }

  // Look for price elements (containing currency symbols)
  const allElements = document.querySelectorAll("*");
  let priceElements = [];
  for (const el of allElements) {
    const text = el.textContent.trim();
    if (
      /[0-9.,]+\s*(?:€|\$|£|TL|₺)/.test(text) ||
      /(?:€|\$|£|TL|₺)\s*[0-9.,]+/.test(text)
    ) {
      priceElements.push({
        element: el.tagName,
        text: text,
        classes: el.className,
      });
    }
  }

  if (priceElements.length > 0) {
    result.foundElements.prices = priceElements.slice(0, 3); // Limit to first 3 found
  }

  // Look for add to cart buttons
  const buttons = document.querySelectorAll(
    'button, a.button, .btn, [role="button"]'
  );
  const cartButtons = [];
  for (const btn of buttons) {
    const text = btn.textContent.toLowerCase().trim();
    if (
      text.includes("cart") ||
      text.includes("bag") ||
      text.includes("basket") ||
      text.includes("buy") ||
      text.includes("add") ||
      text.includes("purchase")
    ) {
      cartButtons.push({
        element: btn.tagName,
        text: btn.textContent.trim(),
        classes: btn.className,
      });
    }
  }

  if (cartButtons.length > 0) {
    result.foundElements.cartButtons = cartButtons.slice(0, 2); // Limit to first 2 found
  }

  // Look for product images
  const images = document.querySelectorAll("img");
  const largeImages = [];
  for (const img of images) {
    const rect = img.getBoundingClientRect();
    if (rect.width > 200 && rect.height > 200) {
      largeImages.push({
        width: rect.width,
        height: rect.height,
        src: img.src,
        alt: img.alt,
        classes: img.className,
      });
    }
  }

  if (largeImages.length > 0) {
    result.foundElements.images = largeImages.slice(0, 2); // Limit to first 2 found
  }

  // Check page metadata
  const ogTitle = document
    .querySelector('meta[property="og:title"]')
    ?.getAttribute("content");
  const ogType = document
    .querySelector('meta[property="og:type"]')
    ?.getAttribute("content");
  const ogImage = document
    .querySelector('meta[property="og:image"]')
    ?.getAttribute("content");

  if (ogTitle || ogType || ogImage) {
    result.foundElements.openGraph = {
      title: ogTitle,
      type: ogType,
      image: ogImage,
    };
  }

  // Look for sizes and colors specifically
  findSizesAndColors(result);

  log("Emergency product detection results:", result);
  return result;
}

// Helper function to find sizes and colors specifically
function findSizesAndColors(result) {
  // Look for any Select2 dropdowns (which might contain sizes)
  const select2Elements = document.querySelectorAll(
    ".select2-container, .select2-dropdown, .select2-results"
  );
  if (select2Elements.length > 0) {
    log(`Found ${select2Elements.length} Select2 elements`);

    result.foundElements.select2 = {
      count: select2Elements.length,
      classes: Array.from(select2Elements)
        .map((el) => el.className)
        .join(" | "),
    };

    // Look for size options within Select2
    const sizeContents = document.querySelectorAll(
      ".custom-select-content-size"
    );
    if (sizeContents.length > 0) {
      result.foundElements.select2Sizes = Array.from(sizeContents).map((el) =>
        el.textContent.trim()
      );
      log(`Found ${sizeContents.length} sizes in Select2`);
    }
  }

  // Look for carousel/slick elements (which might contain colors)
  const carouselElements = document.querySelectorAll(
    ".slick-track, .carousel, .slick-slider"
  );
  if (carouselElements.length > 0) {
    log(`Found ${carouselElements.length} carousel/slider elements`);

    result.foundElements.carousels = {
      count: carouselElements.length,
      classes: Array.from(carouselElements)
        .map((el) => el.className)
        .join(" | "),
    };

    // Look for tooltip content which might have color names
    const tooltipContents = document.querySelectorAll(
      "[data-gg-tooltip--content]"
    );
    if (tooltipContents.length > 0) {
      result.foundElements.tooltipColors = Array.from(tooltipContents).map(
        (el) => el.textContent.trim()
      );
      log(`Found ${tooltipContents.length} tooltip contents (possibly colors)`);
    }
  }
}

// Helper function to log overall page structure
function logPageStructure() {
  try {
    log("Analyzing page structure");

    // Check for common product page containers
    const containers = [
      {
        name: "Product detail container",
        selector: '.product-detail, .pdp, [class*="product-detail"]',
      },
      {
        name: "Add to cart form",
        selector:
          'form[action*="cart"], form[action*="bag"], [id*="shopping-bag-form"]',
      },
      {
        name: "Product info section",
        selector: ".product-info, .pdp-info, .product-details",
      },
      {
        name: "Size selector",
        selector: '.size-dropdown, .size-selector, [class*="size"]',
      },
      {
        name: "Color selector",
        selector: '.color-carousel, .color-selector, [class*="color"]',
      },
      {
        name: "Price element",
        selector: '.price, [class*="price"], [class*="Price"]',
      },
    ];

    let structureInfo = {};

    for (const container of containers) {
      const elements = document.querySelectorAll(container.selector);
      if (elements.length > 0) {
        structureInfo[container.name] = {
          count: elements.length,
          classes: Array.from(elements)
            .slice(0, 2)
            .map((el) => el.className)
            .join(" | "),
        };
      }
    }

    log("Page structure analysis:", structureInfo);

    // Look for Select2 initialization in scripts
    const scripts = document.querySelectorAll("script:not([src])");
    let foundSelect2 = false;

    for (const script of scripts) {
      if (
        script.textContent.includes("select2") ||
        script.textContent.includes("Select2")
      ) {
        foundSelect2 = true;
        log("Found Select2 initialization in scripts");
        break;
      }
    }

    if (!foundSelect2) {
      log("No Select2 initialization found in scripts");
    }

    // Look for slick carousel initialization in scripts
    let foundSlick = false;
    for (const script of scripts) {
      if (
        script.textContent.includes("slick(") ||
        script.textContent.includes(".slick(")
      ) {
        foundSlick = true;
        log("Found Slick carousel initialization in scripts");
        break;
      }
    }

    if (!foundSlick) {
      log("No Slick carousel initialization found in scripts");
    }
  } catch (e) {
    log("Error analyzing page structure:", e);
  }
}

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

    // Try emergency detection if not successful and it's the last retry
    if (
      (!productInfo.isProductPage || !productInfo.success) &&
      retryCount >= CONFIG.maxRetries - 1
    ) {
      const emergencyResults = findAnyProductInfo();
      productInfo.emergencyResults = emergencyResults;

      // If we found a title and price in emergency mode, try to use it
      if (
        emergencyResults.foundElements.title &&
        emergencyResults.foundElements.prices
      ) {
        // Check if URL looks like a product
        const url = window.location.href;
        if (
          url.includes("/pr/") ||
          url.includes("/p/") ||
          url.includes("-p-")
        ) {
          log(
            "URL suggests this is a product page, using emergency detection results"
          );

          // Update product info with emergency results
          productInfo.isProductPage = true;
          productInfo.title = emergencyResults.foundElements.title.text;

          // Try to extract price from found price text
          if (emergencyResults.foundElements.prices.length > 0) {
            const priceText = emergencyResults.foundElements.prices[0].text;
            productInfo.price = formatPrice(priceText);
            productInfo.currency = detectCurrency(priceText);

            // Get image if available
            if (
              emergencyResults.foundElements.images &&
              emergencyResults.foundElements.images.length > 0
            ) {
              productInfo.imageUrl =
                emergencyResults.foundElements.images[0].src;
            }

            // Try to add sizes if found in emergency mode
            if (
              emergencyResults.foundElements.select2Sizes &&
              emergencyResults.foundElements.select2Sizes.length > 0
            ) {
              productInfo.variants = productInfo.variants || {
                colors: [],
                sizes: [],
                otherOptions: [],
              };

              for (const sizeText of emergencyResults.foundElements
                .select2Sizes) {
                productInfo.variants.sizes.push({
                  text: sizeText,
                  selected: false,
                  value: sizeText,
                });
              }

              log(
                `Added ${emergencyResults.foundElements.select2Sizes.length} sizes from emergency detection`
              );
            }

            // Try to add colors if found in emergency mode
            if (
              emergencyResults.foundElements.tooltipColors &&
              emergencyResults.foundElements.tooltipColors.length > 0
            ) {
              productInfo.variants = productInfo.variants || {
                colors: [],
                sizes: [],
                otherOptions: [],
              };

              for (const colorText of emergencyResults.foundElements
                .tooltipColors) {
                productInfo.variants.colors.push({
                  text: colorText,
                  selected: false,
                  value: colorText,
                });
              }

              log(
                `Added ${emergencyResults.foundElements.tooltipColors.length} colors from emergency detection`
              );
            }

            productInfo.success = true;
            productInfo.extractionMethod = "emergency_detection";

            log("Emergency product detection successful!", productInfo);
          }
        }
      }
    }

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
