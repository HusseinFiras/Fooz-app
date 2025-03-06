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
(function() {
    // Start script with delay to ensure page is fully loaded
    setTimeout(initProductDetector, 1000);
  })();
  
  /**
   * Main function to initialize product detection
   */
  function initProductDetector() {
    // Configuration
    const CHECK_INTERVAL = 1000; // How often to check for updates (1 second)
    const MAX_RETRIES = 8;       // Maximum number of times to retry extracting product info
    const RETRY_DELAY = 800;     // Delay between retries (0.8 second)
    
    let retryCount = 0;
    let lastProductData = null;
    let productDetected = false;
    let observer = null;
    
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
        if (lastProductData.title === productData.title && 
            lastProductData.price === productData.price) {
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
        return true;
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
    
    // Initial detection
    detectAndReportProduct();
    retryDetection();
    
    // Setup mutation observer to detect DOM changes (dynamic content loading)
    observer = new MutationObserver((mutations) => {
      // Only check if we don't have a product yet or if significant mutations occurred
      if (!productDetected || mutations.length > 5) {
        detectAndReportProduct();
      }
    });
    
    observer.observe(document.body, { 
      subtree: true, 
      childList: true,
      attributes: true,
      attributeFilter: ['style', 'class', 'src', 'content'] // Watch attributes that might affect product data
    });
    
    // Also check periodically
    const intervalId = setInterval(() => {
      detectAndReportProduct();
      
      // If we've already detected a product and reported it,
      // we can reduce check frequency to save resources
      if (productDetected) {
        clearInterval(intervalId);
        
        // Continue checking but less frequently
        setInterval(detectAndReportProduct, CHECK_INTERVAL * 5);
        
        // And stop the aggressive retries
        retryCount = MAX_RETRIES;
      }
    }, CHECK_INTERVAL);
    
    // Setup page navigation monitoring
    let lastUrl = window.location.href;
    setInterval(() => {
      const currentUrl = window.location.href;
      if (currentUrl !== lastUrl) {
        // URL changed, reset detection
        lastUrl = currentUrl;
        lastProductData = null;
        productDetected = false;
        retryCount = 0;
        
        // Reset page state in Flutter
        reportToFlutter({
          isProductPage: false,
          success: false,
          navigated: true,
          url: currentUrl
        });
        
        // Try to detect on the new page
        setTimeout(() => {
          detectAndReportProduct();
          retryDetection();
        }, 1000);
      }
    }, 500);
  }
  
  /**
   * Function to check if current page is a product page
   */
  function isProductPage() {
    // 1. Check URL patterns
    const url = window.location.href;
    const productUrlPatterns = [
      /\/p\//, /\/product\//, /\/item\//, /\/pd\//, 
      /\/products\//, /\/urun\//, /\/detay\//, 
      /\/ProductDetails/, /\/productdetail/,
      /\/goods\//, /\/shop\/products\//, /\/product-p/,
      /\/[a-z0-9-_]{6,}\/p\/[a-z0-9-_]{6,}/
    ];
    
    if (productUrlPatterns.some(pattern => pattern.test(url))) {
      return true;
    }
    
    // 2. Check for schema.org product markup
    const jsonLdScripts = document.querySelectorAll('script[type="application/ld+json"]');
    for (const script of jsonLdScripts) {
      try {
        const data = JSON.parse(script.textContent);
        if (data['@type'] === 'Product' || 
            (Array.isArray(data) && data.some(item => item['@type'] === 'Product'))) {
          return true;
        }
      } catch (e) {
        // JSON parsing error, continue to next script
      }
    }
    
    // 3. Check for product-specific meta tags
    if (document.querySelector('meta[property="og:type"][content="product"]') ||
        document.querySelector('meta[property="product:price:amount"]')) {
      return true;
    }
    
    // 4. Check for common product page elements
    const productIndicators = [
      // Add to cart buttons
      '.add-to-cart', '#addToCart', '[data-button-action="add-to-cart"]',
      '.btn-add-to-cart', '.addtocart', '.AddToCart', '.sepeteekle',
      // Product galleries
      '.product-gallery', '.product-images', '.product-photos',
      '.product-image-gallery', '.urun-resimleri',
      // Product options (like size/color selectors)
      '.product-options', '.product-variants', '.size-selector',
      '.variant-options', '.product-form__variants', '.urun-secenekleri'
    ];
    
    if (productIndicators.some(selector => document.querySelector(selector))) {
      return true;
    }
    
    // 5. Check for typical product page structure
    const hasPrice = document.querySelector('[itemprop="price"]') || 
                    !!document.body.innerText.match(/[0-9]+[,.][0-9]+\s*(TL|₺|\$|€|£)/);
    
    const hasProductTitle = document.querySelector('h1') && 
                           document.querySelectorAll('h1').length < 3; // Usually just one main title
    
    return hasPrice && hasProductTitle;
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
      extractionMethod: null,
      url: window.location.href,
      timestamp: new Date().toISOString(),
      success: false
    };
    
    if (!result.isProductPage) {
      return result;
    }
    
    // Use multiple methods to extract data, starting with the most reliable
    
    // Method 1: Structured data (schema.org)
    const structuredData = extractFromStructuredData();
    if (structuredData.success) {
      Object.assign(result, structuredData);
      result.extractionMethod = 'structured_data';
      result.success = true;
      return result;
    }
    
    // Method 2: Meta tags
    const metaTags = extractFromMetaTags();
    if (metaTags.success) {
      Object.assign(result, metaTags);
      result.extractionMethod = 'meta_tags';
      result.success = true;
      return result;
    }
    
    // Method 3: Common selectors
    const commonSelectors = extractFromCommonSelectors();
    if (commonSelectors.success) {
      Object.assign(result, commonSelectors);
      result.extractionMethod = 'common_selectors';
      result.success = true;
      return result;
    }
    
    // Method 4: Content scanning (least reliable, but fallback)
    const contentScan = scanContentForProductInfo();
    if (contentScan.success) {
      Object.assign(result, contentScan);
      result.extractionMethod = 'content_scan';
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
      success: false
    };
    
    const jsonLdScripts = document.querySelectorAll('script[type="application/ld+json"]');
    for (const script of jsonLdScripts) {
      try {
        const data = JSON.parse(script.textContent);
        
        // Function to find product data regardless of nesting
        const findProduct = (obj) => {
          if (!obj) return null;
          
          if (obj['@type'] === 'Product') {
            return obj;
          }
          
          if (Array.isArray(obj)) {
            for (const item of obj) {
              const result = findProduct(item);
              if (result) return result;
            }
          } else if (typeof obj === 'object') {
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
            if (typeof product.brand === 'string') {
              result.brand = product.brand;
            } else if (product.brand.name) {
              result.brand = product.brand.name;
            }
          }
          
          // Handle image URLs
          if (product.image) {
            if (typeof product.image === 'string') {
              result.imageUrl = product.image;
            } else if (Array.isArray(product.image) && product.image.length > 0) {
              result.imageUrl = product.image[0].url || product.image[0];
            } else if (product.image.url) {
              result.imageUrl = product.image.url;
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
      success: false
    };
    
    // Product title
    const titleMeta = document.querySelector('meta[property="og:title"], meta[name="twitter:title"]');
    if (titleMeta) {
      result.title = titleMeta.getAttribute('content');
    }
    
    // Product price
    const priceMeta = document.querySelector('meta[property="product:price:amount"], meta[property="og:price:amount"]');
    if (priceMeta) {
      const price = priceMeta.getAttribute('content');
      if (price && !isNaN(parseFloat(price))) {
        result.price = price;
      }
    }
    
    // Currency
    const currencyMeta = document.querySelector('meta[property="product:price:currency"], meta[property="og:price:currency"]');
    if (currencyMeta) {
      result.currency = currencyMeta.getAttribute('content');
    }
    
    // Product image
    const imageMeta = document.querySelector('meta[property="og:image"], meta[name="twitter:image"]');
    if (imageMeta) {
      result.imageUrl = imageMeta.getAttribute('content');
    }
    
    // Product description
    const descMeta = document.querySelector('meta[property="og:description"], meta[name="twitter:description"], meta[name="description"]');
    if (descMeta) {
      result.description = descMeta.getAttribute('content');
    }
    
    // Brand
    const brandMeta = document.querySelector('meta[property="product:brand"], meta[property="og:brand"]');
    if (brandMeta) {
      result.brand = brandMeta.getAttribute('content');
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
      success: false
    };
    
    // Title selectors (optimized for e-commerce sites)
    const titleSelectors = [
      'h1.product-title', 'h1.product-name', '.product-title h1', 
      '.product-info h1', '.product-single__title', '.product-name h1',
      '#productTitle', '.product_title', '[itemprop="name"]', 
      '.product-detail-name', '.urun-adi', '.productName', 
      // If all else fails, just the first h1 if there's only one
      'h1'
    ];
    
    // Price selectors (optimized for e-commerce sites)
    const priceSelectors = [
      '.price', '.product-price', '.price-sales', 
      '.current-price', '[data-price-type="finalPrice"]', '[itemprop="price"]',
      '.price-box .price', '.price-current', '.offer-price',
      '.price-container', '.current', '.now', '.urun-fiyat',
      '.fiyat', '.indirimliFiyat', '.satisFiyat', '.product-price-tr',
      '.prc-dsc'
    ];
    
    // Original price selectors (for discounted items)
    const oldPriceSelectors = [
      '.old-price', '.original-price', '.regular-price', '.was-price',
      '.price-old', '.list-price', '.price-before-discount',
      '.compare-at-price', '.eski-fiyat', '.previous-price'
    ];
    
    // Image selectors
    const imageSelectors = [
      '.product-image img', '.product-single__image', 
      '.product-gallery__image', '[itemprop="image"]',
      '.product-photo-container img', '#product-image',
      '.ProductItem__Image', '.gallery-image',
      '.urun-resim img', '.product-image-tr img',
      // Try the first large image in the product area
      '.product-detail img', '.product-main img', '.detail img'
    ];
    
    // Description selectors
    const descriptionSelectors = [
      '.product-description', '.description', '[itemprop="description"]',
      '.product-short-description', '.product-info__description',
      '.urun-aciklama', '.productDescription'
    ];
    
    // SKU selectors
    const skuSelectors = [
      '[itemprop="sku"]', '.sku', '.product-sku', 
      '.product-meta__sku', '.urun-kod', '.productSku'
    ];
    
    // Availability selectors
    const availabilitySelectors = [
      '[itemprop="availability"]', '.stock-level', '.availability',
      '.product-stock', '.urun-stok'
    ];
    
    // Brand selectors
    const brandSelectors = [
      '[itemprop="brand"]', '.brand', '.product-brand',
      '.product-meta__vendor', '.marka', '.productBrand'
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
            let price = match[1].replace(/\./g, '').replace(',', '.');
            result.price = price;
            
            // Try to determine currency
            if (text.includes('TL') || text.includes('₺')) {
              result.currency = 'TRY';
            } else if (text.includes('$')) {
              result.currency = 'USD';
            } else if (text.includes('€')) {
              result.currency = 'EUR';
            } else if (text.includes('£')) {
              result.currency = 'GBP';
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
            result.originalPrice = match[1].replace(/\./g, '').replace(',', '.');
            break;
          }
        }
      }
      if (result.originalPrice) break;
    }
    
    // Try to find image
    for (const selector of imageSelectors) {
      const element = document.querySelector(selector);
      if (element && (element.getAttribute('src') || element.getAttribute('data-src'))) {
        let src = element.getAttribute('src') || element.getAttribute('data-src');
        // Convert relative URLs to absolute
        if (src && src.startsWith('/')) {
          src = window.location.origin + src;
        }
        result.imageUrl = src;
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
      success: false
    };
    
    // Get probable title (usually the first h1 on a product page)
    const h1 = document.querySelector('h1');
    if (h1 && h1.textContent.trim()) {
      result.title = h1.textContent.trim();
    } else {
      // Fallback to title tag
      const titleTag = document.querySelector('title');
      if (titleTag && titleTag.textContent.trim()) {
        result.title = titleTag.textContent.trim();
      }
    }
    
    // Scan for price patterns in text nodes
    const priceRegex = /([0-9]+[.,][0-9]+)\s*(?:TL|₺|\$|€|£)/ig;
    const textNodes = [];
    
    // Function to collect all text nodes
    function collectTextNodes(node) {
      if (node.nodeType === Node.TEXT_NODE) {
        const text = node.textContent.trim();
        if (text && text.length > 0) {
          textNodes.push({
            node: node,
            text: text,
            parent: node.parentElement
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
          currency: match[0].includes('TL') || match[0].includes('₺') ? 'TRY' : 
                  (match[0].includes('$') ? 'USD' : 
                  (match[0].includes('€') ? 'EUR' : 
                  (match[0].includes('£') ? 'GBP' : null))),
          element: textNode.parent,
          text: match[0]
        });
      }
    }
    
    // Try to find images that might be product images
    const largeImages = Array.from(document.querySelectorAll('img'))
      .filter(img => {
        const rect = img.getBoundingClientRect();
        return rect.width > 200 && rect.height > 200;
      })
      .map(img => img.src || img.getAttribute('data-src'))
      .filter(src => src);
    
    if (largeImages.length > 0) {
      result.imageUrl = largeImages[0];
    }
    
    // Select most likely price (closest to product title or largest on page)
    if (priceMatches.length > 0) {
      // Default to first match
      let bestMatch = priceMatches[0];
      
      if (result.title) {
        // Try to find price closest to title
        const titleElement = document.querySelector('h1');
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
      
      result.price = bestMatch.price.replace(/\./g, '').replace(',', '.');
      result.currency = bestMatch.currency;
      
      // Try to find original price near the current price
      if (bestMatch.element) {
        const nearbyText = bestMatch.element.innerText || '';
        const oldPriceMatch = nearbyText.match(/([0-9]+[.,][0-9]+)/g);
        if (oldPriceMatch && oldPriceMatch.length > 1) {
          // Find a price different from the current price
          for (const price of oldPriceMatch) {
            const cleanPrice = price.replace(/\./g, '').replace(',', '.');
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