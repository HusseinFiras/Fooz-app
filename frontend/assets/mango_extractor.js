// mango_extractor.js
// Specialized extractor for Mango website products
console.log('💼 Mango extractor module loaded');

// Import utilities used in the extractor
// These will be made available by product_detector.js when it loads this file
// const Logger = window.ProductDetectorUtils.Logger;
// const DOMUtils = window.ProductDetectorUtils.DOMUtils;
// const FormatUtils = window.ProductDetectorUtils.FormatUtils;
// const BaseExtractor = window.ProductDetectorUtils.BaseExtractor;

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
            
            // For Mango we need a specific approach for checking availability
            let isInStock = !isDisabled;
            
            // Check for delayed delivery information (specific to Mango)
            let hasDelayedDelivery = false;
            let deliveryInfo = null;
            
            // Special handling for Mango sizes
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
                      // Process size data if found
                      if (sizeData.sizes || sizeData.size) {
                        const sizes = sizeData.sizes || sizeData.size;
                        
                        // Handle different formats - array or object
                        if (Array.isArray(sizes)) {
                          for (const size of sizes) {
                            // Add size if it has name/text property
                            if (size.name || size.text) {
                              sizeVariants.push({
                                text: size.name || size.text,
                                selected: size.selected || false,
                                value: JSON.stringify({
                                  size: size.name || size.text,
                                  inStock: size.inStock !== false, // Default to true
                                  delayedDelivery: false
                                })
                              });
                            }
                          }
                        }
                        
                        // If we found sizes, add to result and exit loop
                        if (sizeVariants.length > 0) {
                          result.variants.sizes = sizeVariants;
                          break;
                        }
                      }
                    } catch (innerJsonError) {
                      // Ignore individual JSON parse errors
                    }
                  }
                }
              } catch (jsonError) {
                Logger.error("Error parsing size JSON:", jsonError);
              }
            }
          }
        }
        
        if (sizeVariants.length === 0) {
          Logger.warn("Could not extract size information from Mango product");
        }
      } catch (e) {
        Logger.error("Error extracting Mango sizes:", e);
      }
      
      // Mark extraction as successful if we have the minimum data
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
  },
  
  // Method to check if a URL is a Mango product page
  isMangoProductUrl: function(url) {
    if (!url || !url.includes("mango.com")) return false;
    
    // Mango product URLs have /p/ pattern in them
    // Example: https://shop.mango.com/tr/tr/p/erkek/gomlek/slim-fit/dar-kesimli-100-pamuklu-gomlek_87067899
    const mangoProductPattern = /mango\.com\/.*\/p\//;
    return mangoProductPattern.test(url);
  },
  
  // Method to check if a URL is a Mango category/non-product page
  isMangoNonProductUrl: function(url) {
    if (!url || !url.includes("mango.com")) return false;
    
    // Mango category pages generally have /h/ pattern
    const mangoNonProductPattern = /mango\.com\/.*\/h\//;
    return mangoNonProductPattern.test(url);
  }
};

// Export the extractor
if (typeof module !== 'undefined' && module.exports) {
  module.exports = MangoExtractor;
} else {
  // For browser context
  window.MangoExtractor = MangoExtractor;
} 