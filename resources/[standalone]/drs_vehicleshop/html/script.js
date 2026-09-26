"use strict";

let categories = {};
let vehicles = {};
let currentCategory = "all";
let currentBrand = null;
let currentSort = "name";
let sortOrder = "asc";
let inTestDrive = false;
let observer = null;
let searchDebounce = null;
let lastFocusedCard = null;
let selectedVehicle = null;
let checkoutConfig = null;
let checkoutStage = "details";
let checkoutDraft = null;
let activeQuote = null;
let checkoutBusy = null;
let checkoutError = "";
let checkoutRequestToken = 0;
const recentVehicleStoragePrefix = "drs_vehicleshop:recent:v1:";
const maxStoredShopIdLength = 48;
const maxStoredShopTypeLength = 16;
const maxStoredModelLength = 64;
const maxCategoryIdLength = 64;
const imageProbeCache = new Map();
const imageLoadTokens = new WeakMap();
const checkoutIdPattern = /^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$/;
const safeSwatchPattern = /^#[0-9A-Fa-f]{3}(?:[0-9A-Fa-f]{3})?$/;
const safePlateArtworkPattern = /^assets\/plates\/[A-Za-z0-9_-]+\.(?:png|webp)$/;
const featuredColorLimit = 5;
const featuredColorIds = Object.freeze([
  "black",
  "graphite",
  "frost_white",
  "torino_red",
  "bright_blue",
]);
const defaultCheckoutConfig = Object.freeze({
  enabled: true,
  colors: [
    { id: "graphite", label: "Graphite", swatch: "#27282d" },
  ],
  plateStyles: [
    {
      id: "blue_white",
      label: "San Andreas Cursive",
      image: "assets/plates/san-andreas-cursive.png",
    },
  ],
  deliveryModes: [
    {
      id: "driveaway",
      label: "Drive away",
      description: "Collect your vehicle at the showroom.",
    },
  ],
  defaults: {
    primaryColorId: "graphite",
    secondaryColorId: "graphite",
    plateMode: "standard",
    plateStyleId: "blue_white",
    deliveryMode: "driveaway",
  },
  capabilities: {
    colors: false,
    secondaryColor: false,
    platePrefix: true,
    plateStyles: false,
    delivery: false,
  },
});
const defaultShopPresentations = {
  car: {
    image: "assets/shops/auto.webp",
    logo: "assets/shops/pdm.svg",
    eyebrow: "Premium Deluxe Motorsport",
    title: "Choose a vehicle to begin",
    description:
      "Explore the showroom, compare performance, and select a vehicle to unlock its purchase and test-drive options.",
    details: [
      {
        label: "Showroom",
        value: "Road-ready inventory across every public vehicle class",
      },
      {
        label: "Test drives",
        value: "Five-minute supervised route from the dealership",
      },
      {
        label: "Delivery",
        value: "Direct handoff or secure garage staging",
      },
    ],
  },
  boat: {
    image: "assets/shops/boat.webp",
    logo: "assets/shops/pds.svg",
    eyebrow: "Puerto Del Sol Marina",
    title: "Choose a vessel to begin",
    description:
      "Browse the marina fleet, review each vessel, and select one to reveal its purchase and water-test options.",
    details: [
      {
        label: "Marina",
        value: "Recreational vessels prepared at Puerto Del Sol",
      },
      {
        label: "Water tests",
        value: "Launch directly into the marina test area",
      },
      {
        label: "Boathouse",
        value: "Purchased vessels register to marina storage",
      },
    ],
  },
  air: {
    image: "assets/shops/air.webp",
    logo: "assets/shops/lsa.svg",
    eyebrow: "Los Santos Air Sales",
    title: "Choose an aircraft to begin",
    description:
      "Review the hangar inventory, compare flight performance, and select an aircraft for purchase or a flight test.",
    details: [
      {
        label: "Hangar",
        value: "Helicopters and fixed-wing aircraft in one catalogue",
      },
      {
        label: "Flight tests",
        value: "Depart from the airport testing apron",
      },
      {
        label: "Storage",
        value: "Purchases register to secure airport storage",
      },
    ],
  },
};
let activeShop = {
  id: "auto",
  label: "Premium Deluxe Motorsport",
  type: "car",
  defaultCategory: "sports",
  categoryOrder: ["sports"],
  presentation: defaultShopPresentations.car,
};

const moneyFormatter = new Intl.NumberFormat("en-US", {
  style: "currency",
  currency: "USD",
  maximumFractionDigits: 0,
});

// These two files intentionally retain their original casing on disk.
const brandLogoOverrides = {
  bollokan: "Bollokan.webp",
  weeny: "Weeny.webp",
};

const container = document.getElementById("container");
const vehicleGrid = document.querySelector(".vehicle-grid");
const vehicleInfo = document.querySelector(".vehicle-info");
const vehicleCount = document.getElementById("vehicleCount");
const counterDescription = document.querySelector(".counter-description");
const searchInput = document.getElementById("searchInput");
const sortSelect = document.getElementById("sortSelect");
const brandSelect = document.getElementById("brandSelect");
const categoriesElement = document.querySelector(".categories");
const timer = document.querySelector(".test-drive-timer");
const timerSeconds = document.querySelector(".timer-seconds");

function asObject(value) {
  return value && typeof value === "object" && !Array.isArray(value)
    ? value
    : {};
}

function asText(value, fallback = "") {
  if (typeof value === "string" || typeof value === "number") {
    return String(value);
  }

  return fallback;
}

function presentationText(value, fallback, maxLength) {
  const text = asText(value)
    .replace(/[\u0000-\u001f\u007f]+/g, " ")
    .replace(/\s+/g, " ")
    .trim();
  return (text || fallback).slice(0, maxLength);
}

function shopTypeKey(shop) {
  const type = asText(shop?.type, "car").toLocaleLowerCase();
  return type === "boat" || type === "air" ? type : "car";
}

function normalizedShopPresentation(value, shop) {
  const raw = asObject(value);
  const fallback = defaultShopPresentations[shopTypeKey(shop)];
  const requestedLogo = asText(raw.logo).trim();
  const logo = /^assets\/shops\/[A-Za-z0-9_-]+\.(?:svg|webp)$/.test(requestedLogo)
    ? requestedLogo
    : fallback.logo;
  const requestedImage = asText(raw.image).trim();
  const image = /^assets\/shops\/[A-Za-z0-9_-]+\.webp$/.test(requestedImage)
    ? requestedImage
    : fallback.image;
  const rawDetails = Array.isArray(raw.details) ? raw.details : [];
  const details = fallback.details.map((fallbackDetail, index) => {
    const detail = asObject(rawDetails[index]);
    return {
      label: presentationText(detail.label, fallbackDetail.label, 32),
      value: presentationText(detail.value, fallbackDetail.value, 112),
    };
  });

  return {
    image,
    logo,
    eyebrow: presentationText(raw.eyebrow, fallback.eyebrow, 48),
    title: presentationText(raw.title, fallback.title, 72),
    description: presentationText(raw.description, fallback.description, 240),
    details,
  };
}

function safeCheckoutId(value) {
  const id = asText(value).trim();
  return checkoutIdPattern.test(id) ? id : null;
}

function checkoutText(value, fallback, maxLength = 72) {
  return presentationText(value, fallback, maxLength);
}

function normalizedCheckoutOptions(value, type, fallback, maxItems) {
  const options = [];
  const seen = new Set();

  (Array.isArray(value) ? value : []).slice(0, maxItems).forEach((entry) => {
    const raw =
      typeof entry === "string" ? { id: entry, label: entry } : asObject(entry);
    const id = safeCheckoutId(raw.id);
    if (!id || seen.has(id)) return;

    if (type === "delivery" && id !== "driveaway" && id !== "garage") return;

    const option = {
      id,
      label: checkoutText(raw.label, id, 48),
    };

    if (type === "color") {
      const swatch = asText(raw.swatch).trim();
      option.swatch = safeSwatchPattern.test(swatch)
        ? swatch
        : "#74777c";
    } else if (type === "plate") {
      option.preview = checkoutText(raw.preview, option.label, 32);
      const artwork = asText(raw.image).trim();
      if (safePlateArtworkPattern.test(artwork)) option.image = artwork;
    } else if (type === "delivery") {
      option.description = checkoutText(
        raw.description,
        id === "garage"
          ? "Store it in a compatible garage."
          : "Collect it at the showroom.",
        120,
      );
    }

    seen.add(id);
    options.push(option);
  });

  if (options.length > 0) return options;
  return fallback.map((option) => ({ ...option }));
}

function optionIdOrDefault(value, options, fallback) {
  const id = safeCheckoutId(value);
  return id && options.some((option) => option.id === id)
    ? id
    : fallback;
}

function booleanCapability(value, fallback) {
  return typeof value === "boolean" ? value : fallback;
}

function normalizedCheckoutConfig(value) {
  const raw = asObject(value);
  const rawDefaults = asObject(raw.defaults);
  const rawCapabilities = asObject(raw.capabilities);
  const colors = normalizedCheckoutOptions(
    raw.colors,
    "color",
    defaultCheckoutConfig.colors,
    24,
  );
  const plateStyles = normalizedCheckoutOptions(
    raw.plateStyles,
    "plate",
    defaultCheckoutConfig.plateStyles,
    8,
  );
  const deliveryModes = normalizedCheckoutOptions(
    raw.deliveryModes,
    "delivery",
    defaultCheckoutConfig.deliveryModes,
    2,
  );

  const defaults = {
    primaryColorId: optionIdOrDefault(
      rawDefaults.primaryColorId,
      colors,
      colors[0].id,
    ),
    secondaryColorId: optionIdOrDefault(
      rawDefaults.secondaryColorId,
      colors,
      colors[0].id,
    ),
    plateMode:
      rawDefaults.plateMode === "prefix" ? "prefix" : "standard",
    plateStyleId: optionIdOrDefault(
      rawDefaults.plateStyleId,
      plateStyles,
      plateStyles[0].id,
    ),
    deliveryMode: optionIdOrDefault(
      rawDefaults.deliveryMode,
      deliveryModes,
      deliveryModes[0].id,
    ),
  };

  const capabilities = {
    colors: booleanCapability(rawCapabilities.colors, colors.length > 1),
    secondaryColor: booleanCapability(
      rawCapabilities.secondaryColor,
      colors.length > 1,
    ),
    platePrefix: booleanCapability(rawCapabilities.platePrefix, true),
    plateStyles: booleanCapability(
      rawCapabilities.plateStyles,
      plateStyles.length > 1,
    ),
    delivery: booleanCapability(
      rawCapabilities.delivery,
      deliveryModes.length > 1,
    ),
  };

  if (!capabilities.platePrefix) defaults.plateMode = "standard";

  return {
    enabled: raw.enabled !== false,
    colors,
    plateStyles,
    deliveryModes,
    defaults,
    capabilities,
  };
}

function newCheckoutDraft() {
  const config = checkoutConfig || normalizedCheckoutConfig(null);
  return {
    primaryColorId: config.defaults.primaryColorId,
    secondaryColorId: config.defaults.secondaryColorId,
    plateMode: config.defaults.plateMode,
    platePrefix: "",
    plateStyleId: config.defaults.plateStyleId,
    deliveryMode: config.defaults.deliveryMode,
  };
}

function resetCheckoutState() {
  checkoutRequestToken += 1;
  checkoutStage = "details";
  checkoutDraft = null;
  activeQuote = null;
  checkoutBusy = null;
  checkoutError = "";
  vehicleInfo.classList.remove("is-checkout", "is-processing");
}

function formatPrice(value) {
  const price = Number(value);
  return moneyFormatter.format(Number.isFinite(price) ? price : 0);
}

function finiteNumber(value) {
  if (value === null || value === "" || typeof value === "boolean") return null;
  const number = Number(value);
  return Number.isFinite(number) ? number : null;
}

function clampRating(value) {
  const number = finiteNumber(value);
  return number === null ? 0 : Math.min(100, Math.max(0, number));
}

function performanceRatingClass(value) {
  const rating = finiteNumber(value);
  if (rating === null) return "rating-unrated";

  const boundedRating = clampRating(rating);
  if (boundedRating < 35) return "rating-poor";
  if (boundedRating < 65) return "rating-average";
  if (boundedRating < 85) return "rating-strong";
  return "rating-elite";
}

function normalizedPerformance(value) {
  const raw = asObject(value);
  const rawTopSpeed = finiteNumber(raw.topSpeed);
  const explicitTopSpeedMph = finiteNumber(raw.topSpeedMph);
  const acceleration = finiteNumber(raw.acceleration);
  const braking = finiteNumber(raw.braking);
  const traction = finiteNumber(raw.traction);
  const hasMetrics =
    rawTopSpeed !== null ||
    explicitTopSpeedMph !== null ||
    acceleration !== null ||
    braking !== null ||
    traction !== null;

  // Newer payloads provide topSpeed in mph. The optional topSpeedMph form is
  // also accepted, in which case topSpeed can remain a normalized rating.
  const topSpeedMph = explicitTopSpeedMph ?? rawTopSpeed;
  const topSpeedRating =
    explicitTopSpeedMph !== null && rawTopSpeed !== null
      ? clampRating(rawTopSpeed)
      : clampRating((topSpeedMph || 0) / 2);

  return {
    supported: raw.supported === true || hasMetrics,
    available: raw.available === true || (raw.available !== false && hasMetrics),
    topSpeedMph,
    topSpeedRating: topSpeedMph === null ? null : topSpeedRating,
    acceleration: acceleration === null ? null : clampRating(acceleration),
    braking: braking === null ? null : clampRating(braking),
    traction: traction === null ? null : clampRating(traction),
    classId: finiteNumber(raw.classId),
  };
}

function getResourceName() {
  return typeof GetParentResourceName === "function"
    ? GetParentResourceName()
    : "drs_vehicleshop";
}

function postNui(endpoint, payload) {
  return fetch(`https://${getResourceName()}/${endpoint}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: payload === undefined ? undefined : JSON.stringify(payload),
  })
    .then(async (response) => {
      try {
        return await response.json();
      } catch (_) {
        return undefined;
      }
    })
    .catch(() => undefined);
}

function isShopVisible() {
  return !container.classList.contains("hidden");
}

function setShopVisible(show) {
  container.classList.toggle("hidden", !show);
  container.setAttribute("aria-hidden", String(!show));
}

function showTestDriveTimer(show) {
  timer.classList.toggle("active", show);
  timer.classList.remove("warning");
  timer.setAttribute("aria-hidden", String(!show));

  if (!show) {
    timerSeconds.textContent = "--";
  }
}

function updateTimerDisplay(value) {
  const seconds = Math.max(0, Number.parseInt(value, 10) || 0);
  timerSeconds.textContent = String(seconds).padStart(2, "0");
  timer.classList.toggle("warning", seconds <= 10);
  timer.setAttribute(
    "aria-label",
    `Test drive time remaining: ${seconds} second${seconds === 1 ? "" : "s"}`,
  );
}

function normalizedVehicle(rawVehicle, categoryKey) {
  const raw = asObject(rawVehicle);
  return {
    ...raw,
    name: asText(raw.name, "Unnamed vehicle"),
    brand: asText(raw.brand, "Unknown brand"),
    model: asText(raw.model, "unknown"),
    category: asText(raw.category, categoryKey || "unknown"),
    price: Number(raw.price) || 0,
    isAddon: raw.isAddon === true,
    performance: normalizedPerformance(raw.performance),
  };
}

function allVehiclesForCategory(categoryKey) {
  const list = [];
  const categoryEntries =
    categoryKey === "all"
      ? Object.entries(vehicles)
      : [[categoryKey, vehicles[categoryKey] || {}]];

  categoryEntries.forEach(([key, categoryVehicles]) => {
    Object.values(asObject(categoryVehicles)).forEach((vehicle) => {
      list.push(normalizedVehicle(vehicle, key));
    });
  });

  return list;
}

function storageIdentifier(value, maxLength) {
  if (typeof value !== "string") return null;

  const identifier = value.trim().toLocaleLowerCase();
  if (
    identifier.length === 0 ||
    identifier.length > maxLength ||
    !/^[a-z0-9_-]+$/.test(identifier)
  ) {
    return null;
  }

  return identifier;
}

function normalizedCategoryKey(value) {
  return storageIdentifier(value, maxCategoryIdLength);
}

function categoryHasInventory(categoryKey) {
  const key = normalizedCategoryKey(categoryKey);
  return Boolean(
    key &&
      Object.prototype.hasOwnProperty.call(categories, key) &&
      Object.keys(asObject(vehicles[key])).length > 0,
  );
}

function normalizedCategoryOrder(value) {
  const ordered = [];
  const seen = new Set();

  const addCategory = (rawCategory) => {
    const category = normalizedCategoryKey(rawCategory);
    if (!category || seen.has(category) || !categoryHasInventory(category)) return;
    seen.add(category);
    ordered.push(category);
  };

  (Array.isArray(value) ? value : []).slice(0, 64).forEach(addCategory);
  Object.keys(categories)
    .sort((left, right) => {
      const leftLabel = asText(categories[left], left);
      const rightLabel = asText(categories[right], right);
      return leftLabel.localeCompare(rightLabel) || left.localeCompare(right);
    })
    .forEach(addCategory);

  return ordered;
}

function openingCategory() {
  if (categoryHasInventory(activeShop.defaultCategory)) {
    return activeShop.defaultCategory;
  }

  const fallback = activeShop.categoryOrder?.find(categoryHasInventory);
  return fallback || "all";
}

function recentVehicleStorageKey() {
  const shopType = storageIdentifier(activeShop?.type, maxStoredShopTypeLength);
  const shopId = storageIdentifier(activeShop?.id, maxStoredShopIdLength);
  return shopType && shopId
    ? `${recentVehicleStoragePrefix}${shopType}:${shopId}`
    : null;
}

function forgetRecentVehicle() {
  const key = recentVehicleStorageKey();
  if (!key) return;

  try {
    window.localStorage.removeItem(key);
  } catch (_) {
    // Persistence is optional when the NUI storage origin is unavailable.
  }
}

function readRecentVehicleModel() {
  const key = recentVehicleStorageKey();
  if (!key) return null;

  try {
    const storedValue = window.localStorage.getItem(key);
    if (storedValue === null) return null;

    const model = storageIdentifier(storedValue, maxStoredModelLength);
    if (!model) window.localStorage.removeItem(key);
    return model;
  } catch (_) {
    return null;
  }
}

function rememberRecentVehicle(model) {
  const key = recentVehicleStorageKey();
  const storedModel = storageIdentifier(model, maxStoredModelLength);
  if (!key || !storedModel) return;

  try {
    window.localStorage.setItem(key, storedModel);
  } catch (_) {
    // Full or disabled localStorage must never prevent catalogue interaction.
  }
}

function restoreRecentVehicle() {
  const storedModel = readRecentVehicleModel();
  if (!storedModel) return null;

  let vehicle = null;

  for (const categoryKey of normalizedCategoryOrder(activeShop.categoryOrder)) {
    const categoryVehicles = vehicles[categoryKey];
    const rawVehicle = Object.values(asObject(categoryVehicles)).find(
      (candidate) =>
        storageIdentifier(candidate?.model, maxStoredModelLength) === storedModel,
    );
    if (!rawVehicle) continue;

    vehicle = normalizedVehicle(rawVehicle, categoryKey);
    vehicle.category = categoryKey;
    break;
  }

  if (!vehicle) forgetRecentVehicle();
  return vehicle || null;
}

function scrollVehicleCardIntoView(model) {
  const storedModel = storageIdentifier(model, maxStoredModelLength);
  if (!storedModel) return;

  window.requestAnimationFrame(() => {
    const card = Array.from(
      vehicleGrid.querySelectorAll(".vehicle-card"),
    ).find(
      (candidate) =>
        storageIdentifier(candidate.dataset.model, maxStoredModelLength) ===
        storedModel,
    );
    if (!card) return;

    const gridRect = vehicleGrid.getBoundingClientRect();
    const cardRect = card.getBoundingClientRect();
    const centeredTop =
      vehicleGrid.scrollTop +
      cardRect.top -
      gridRect.top -
      (gridRect.height - cardRect.height) / 2;
    vehicleGrid.scrollTop = Math.max(0, centeredTop);
    lastFocusedCard = card;
    card._hydrateVehicleImage?.("high");
  });
}

function filteredVehicles() {
  const searchTerm = searchInput.value.trim().toLocaleLowerCase();
  let list = allVehiclesForCategory(currentCategory);

  if (currentBrand) {
    list = list.filter((vehicle) => vehicle.brand === currentBrand);
  }

  if (searchTerm) {
    list = list.filter((vehicle) =>
      [vehicle.name, vehicle.brand, vehicle.category, vehicle.model].some(
        (value) => value.toLocaleLowerCase().includes(searchTerm),
      ),
    );
  }

  return list;
}

function sortVehicles(list) {
  const direction = sortOrder === "desc" ? -1 : 1;

  return [...list].sort((a, b) => {
    let comparison;

    if (currentSort === "price") {
      comparison = a.price - b.price;
    } else if (currentSort === "brand") {
      comparison = a.brand.localeCompare(b.brand);
    } else {
      comparison = a.name.localeCompare(b.name);
    }

    if (comparison === 0) {
      comparison = a.model.localeCompare(b.model);
    }

    return comparison * direction;
  });
}

function updateCounter(count) {
  const searchTerm = searchInput.value.trim();
  vehicleCount.textContent = String(count);

  if (searchTerm) {
    counterDescription.textContent = `results for “${searchTerm}”`;
  } else if (currentBrand && currentCategory !== "all") {
    const categoryLabel = asText(categories[currentCategory], currentCategory);
    counterDescription.textContent = `${currentBrand} vehicles in ${categoryLabel}`;
  } else if (currentBrand) {
    counterDescription.textContent = `vehicles from ${currentBrand}`;
  } else if (currentCategory !== "all") {
    const categoryLabel = asText(categories[currentCategory], currentCategory);
    counterDescription.textContent = `vehicles in ${categoryLabel}`;
  } else {
    counterDescription.textContent = "vehicles available";
  }
}

function explicitVehicleImageUrl(vehicle) {
  const fileName = asText(vehicle.image).split(/[\\/]/).pop();
  return fileName
    ? `assets/vehicles/${encodeURIComponent(fileName)}`
    : null;
}

function localModelImageUrl(vehicle) {
  return `assets/vehicles/${encodeURIComponent(
    vehicle.model.toLocaleLowerCase(),
  )}.webp`;
}

function remoteVehicleImageUrl(vehicle) {
  return `https://docs.fivem.net/vehicles/${encodeURIComponent(
    vehicle.model.toLocaleLowerCase(),
  )}.webp`;
}

function vehicleImageCandidates(vehicle) {
  const explicitUrl = explicitVehicleImageUrl(vehicle);
  const localUrl = localModelImageUrl(vehicle);
  const remoteUrl = remoteVehicleImageUrl(vehicle);
  let candidates;

  if (explicitUrl) {
    candidates = [explicitUrl, localUrl, remoteUrl];
  } else if (vehicle.isAddon) {
    candidates = [localUrl, remoteUrl];
  } else {
    // Rockstar/FiveM renders are consistent for vanilla models. Add-on models
    // prefer bundled artwork because an official render normally does not exist.
    candidates = [remoteUrl, localUrl];
  }

  return [...new Set(candidates.filter(Boolean))];
}

function brandLogoUrl(brand) {
  const normalized = brand.toLocaleLowerCase();
  const fileName = brandLogoOverrides[normalized] || `${normalized}.webp`;
  return `assets/carbrands/${encodeURIComponent(fileName)}`;
}

function probeImage(url, priority = "auto") {
  if (imageProbeCache.has(url)) return imageProbeCache.get(url);

  const pending = new Promise((resolve, reject) => {
    const image = new Image();
    image.decoding = "async";

    try {
      image.fetchPriority = priority;
    } catch (_) {
      // Older FiveM CEF builds do not expose fetchPriority.
    }

    image.onload = () => resolve(url);
    image.onerror = () => reject(new Error("Vehicle image unavailable"));
    image.src = url;
  });

  imageProbeCache.set(url, pending);
  return pending;
}

function setVehicleImageState(element, state, url) {
  element.classList.remove("is-loading", "has-image", "is-missing");
  element.classList.add("vehicle-media", state);

  if (url) {
    element.style.backgroundImage = `url(${JSON.stringify(url)})`;
  } else {
    element.style.removeProperty("background-image");
  }
}

async function loadVehicleImage(element, vehicle, priority = "auto") {
  const requestToken = {};
  imageLoadTokens.set(element, requestToken);
  setVehicleImageState(element, "is-loading");

  for (const url of vehicleImageCandidates(vehicle)) {
    try {
      await probeImage(url, priority);
      if (imageLoadTokens.get(element) !== requestToken) return;
      setVehicleImageState(element, "has-image", url);
      element.setAttribute("aria-label", `${vehicle.name} vehicle image`);
      return;
    } catch (_) {
      // Continue through the deterministic fallback chain.
    }
  }

  if (imageLoadTokens.get(element) !== requestToken) return;
  setVehicleImageState(element, "is-missing");
  element.setAttribute("aria-label", `${vehicle.name} image unavailable`);
}

function createBrandLogo(brand, className) {
  const logo = document.createElement("img");
  logo.className = className || "";
  logo.src = brandLogoUrl(brand);
  logo.alt = `${brand} logo`;
  logo.loading = "lazy";
  logo.addEventListener(
    "error",
    () => {
      logo.remove();
    },
    { once: true },
  );
  return logo;
}

function createVehicleCard(vehicle) {
  const card = document.createElement("button");
  card.type = "button";
  card.className = "vehicle-card";
  card.dataset.model = vehicle.model;
  card.setAttribute("aria-pressed", "false");
  card.setAttribute(
    "aria-label",
    `${vehicle.name} by ${vehicle.brand}, ${formatPrice(vehicle.price)}. View details.`,
  );

  const image = document.createElement("div");
  image.className = "vehicle-media is-loading";
  image.setAttribute("role", "img");
  image.setAttribute("aria-label", vehicle.name);

  const availability = document.createElement("span");
  availability.className = "availability-pill";
  availability.textContent = "Available";

  const info = document.createElement("div");
  info.className = "vehicle-info-container";

  const name = document.createElement("h3");
  name.className = "vehicle-name";
  name.textContent = vehicle.name;

  const brand = document.createElement("div");
  brand.className = "vehicle-brand";
  brand.append(createBrandLogo(vehicle.brand));

  const brandName = document.createElement("span");
  brandName.textContent = vehicle.brand;
  brand.append(brandName);

  const footer = document.createElement("div");
  footer.className = "vehicle-card-footer";

  const price = document.createElement("p");
  price.className = "vehicle-price";
  price.textContent = formatPrice(vehicle.price);

  const detailsCue = document.createElement("span");
  detailsCue.className = "details-cue";
  detailsCue.setAttribute("aria-hidden", "true");
  detailsCue.textContent = "›";

  footer.append(price, detailsCue);
  info.append(name, brand, footer);
  card.append(image, availability, info);
  card.addEventListener("click", () => {
    lastFocusedCard = card;
    rememberRecentVehicle(vehicle.model);
    showVehicleInfo(vehicle);
  });

  card._hydrateVehicleImage = (priority = "auto") => {
    if (card.dataset.imageRequested === "true") return;
    card.dataset.imageRequested = "true";
    loadVehicleImage(image, vehicle, priority);
  };
  return card;
}

function showEmptyState() {
  const emptyState = document.createElement("div");
  emptyState.className = "empty-state";

  const icon = document.createElement("span");
  icon.className = "empty-state-icon";
  icon.setAttribute("aria-hidden", "true");

  const title = document.createElement("h3");
  title.textContent = "No vehicles found";

  const description = document.createElement("p");
  description.textContent =
    "Try a different category, brand, or search term to browse more inventory.";

  emptyState.append(icon, title, description);
  vehicleGrid.append(emptyState);
}

function vehicleDetailSignature(vehicle) {
  return JSON.stringify([
    vehicle.name,
    vehicle.brand,
    vehicle.model,
    vehicle.category,
    vehicle.price,
    vehicle.image || null,
    vehicle.isAddon,
    vehicle.performance,
  ]);
}

function displayVehicles(list) {
  updateCounter(list.length);

  if (observer) {
    observer.disconnect();
    observer = null;
  }

  vehicleGrid.replaceChildren();
  vehicleGrid.scrollTop = 0;

  if (list.length === 0) {
    resetCheckoutState();
    selectedVehicle = null;
    renderVehicleInfoEmpty();
    showEmptyState();
    return;
  }

  const fragment = document.createDocumentFragment();
  const cards = list.map((vehicle) => {
    const card = createVehicleCard(vehicle);
    fragment.append(card);
    return card;
  });

  vehicleGrid.append(fragment);

  const visibleSelection = selectedVehicle
    ? list.find((vehicle) => vehicle.model === selectedVehicle.model)
    : null;
  if (visibleSelection) {
    const nextSignature = vehicleDetailSignature(visibleSelection);
    if (
      vehicleInfo.dataset.vehicleModel === visibleSelection.model &&
      vehicleInfo.dataset.vehicleSignature === nextSignature
    ) {
      selectedVehicle = visibleSelection;
      updateSelectedCards(visibleSelection.model);
    } else {
      showVehicleInfo(visibleSelection);
    }
  } else {
    resetCheckoutState();
    selectedVehicle = null;
    updateSelectedCards(null);
    renderVehicleInfoEmpty();
  }

  cards.slice(0, 6).forEach((card) => card._hydrateVehicleImage("high"));

  if (!("IntersectionObserver" in window)) {
    cards.forEach((card) => card._hydrateVehicleImage());
    return;
  }

  observer = new IntersectionObserver(
    (entries, activeObserver) => {
      entries.forEach((entry) => {
        if (!entry.isIntersecting) return;
        entry.target._hydrateVehicleImage();
        activeObserver.unobserve(entry.target);
      });
    },
    {
      root: vehicleGrid,
      rootMargin: "220px",
      threshold: 0.01,
    },
  );

  cards.slice(6).forEach((card) => observer.observe(card));
}

function renderVehicles() {
  displayVehicles(sortVehicles(filteredVehicles()));
}

function setupBrandOptions() {
  const brands = new Set();

  Object.entries(vehicles).forEach(([categoryKey, categoryVehicles]) => {
    Object.values(asObject(categoryVehicles)).forEach((vehicle) => {
      brands.add(normalizedVehicle(vehicle, categoryKey).brand);
    });
  });

  brandSelect.replaceChildren();

  const allBrands = document.createElement("option");
  allBrands.value = "";
  allBrands.textContent = "All brands";
  brandSelect.append(allBrands);

  [...brands]
    .sort((a, b) => a.localeCompare(b))
    .forEach((brand) => {
      const option = document.createElement("option");
      option.value = brand;
      option.textContent = brand;
      brandSelect.append(option);
    });

  brandSelect.value = currentBrand || "";
}

function categoryButton(categoryKey, label) {
  const button = document.createElement("button");
  button.type = "button";
  button.className = "category-btn";
  button.dataset.category = categoryKey;
  button.textContent = label;
  button.classList.toggle("active", currentCategory === categoryKey);
  button.setAttribute("aria-pressed", String(currentCategory === categoryKey));
  button.addEventListener("click", () => showCategory(categoryKey));
  return button;
}

function setupCategories() {
  const fragment = document.createDocumentFragment();
  fragment.append(categoryButton("all", "All vehicles"));

  activeShop.categoryOrder = normalizedCategoryOrder(activeShop.categoryOrder);
  activeShop.categoryOrder.forEach((key) => {
    fragment.append(categoryButton(key, asText(categories[key], key)));
  });

  categoriesElement.replaceChildren(fragment);
}

function showCategory(categoryKey) {
  const normalizedCategory = normalizedCategoryKey(categoryKey);
  currentCategory = categoryKey === "all"
    ? "all"
    : categoryHasInventory(normalizedCategory)
      ? normalizedCategory
      : openingCategory();

  document.querySelectorAll(".category-btn").forEach((button) => {
    const isActive = button.dataset.category === currentCategory;
    button.classList.toggle("active", isActive);
    button.setAttribute("aria-pressed", String(isActive));
  });

  renderVehicles();
}

const vehicleClassNames = {
  0: "Compact",
  1: "Sedan",
  2: "SUV",
  3: "Coupe",
  4: "Muscle",
  5: "Sports classic",
  6: "Sports",
  7: "Super",
  8: "Motorcycle",
  9: "Off-road",
  10: "Industrial",
  11: "Utility",
  12: "Van",
  13: "Cycle",
  14: "Boat",
  15: "Helicopter",
  16: "Plane",
  17: "Service",
  18: "Emergency",
  19: "Military",
  20: "Commercial",
  21: "Train",
  22: "Open wheel",
};

function createStat(label, value) {
  const stat = document.createElement("div");
  stat.className = "stat";

  const statLabel = document.createElement("span");
  statLabel.textContent = label;

  const statValue = document.createElement("span");
  statValue.textContent = value;

  stat.append(statLabel, statValue);
  return stat;
}

function createPerformanceMetric(label, value, rating) {
  const metric = document.createElement("div");
  metric.className = "performance-metric";
  metric.classList.add(performanceRatingClass(rating));

  const copy = document.createElement("div");
  copy.className = "performance-metric-copy";

  const metricLabel = document.createElement("span");
  metricLabel.textContent = label;

  const metricValue = document.createElement("strong");
  metricValue.textContent = value;
  copy.append(metricLabel, metricValue);

  const track = document.createElement("div");
  track.className = "performance-track";
  track.setAttribute("role", "meter");
  track.setAttribute("aria-label", label);
  track.setAttribute("aria-valuemin", "0");
  track.setAttribute("aria-valuemax", "100");
  const numericRating = finiteNumber(rating);
  if (numericRating !== null) {
    track.setAttribute(
      "aria-valuenow",
      String(Math.round(clampRating(numericRating))),
    );
  }
  track.setAttribute("aria-valuetext", value);

  const fill = document.createElement("span");
  fill.style.width = `${clampRating(rating)}%`;
  track.append(fill);
  metric.append(copy, track);
  return metric;
}

function createPerformanceSection(performance) {
  const section = document.createElement("section");
  section.className = "performance-section";
  section.setAttribute("aria-label", "Vehicle performance");

  const header = document.createElement("div");
  header.className = "performance-header";

  const copy = document.createElement("div");
  const eyebrow = document.createElement("span");
  eyebrow.className = "eyebrow";
  eyebrow.textContent = "Handling data";

  const title = document.createElement("h3");
  title.textContent = "Performance profile";
  copy.append(eyebrow, title);
  header.append(copy);

  if (performance.classId !== null) {
    const classLabel = document.createElement("span");
    classLabel.className = "performance-class";
    classLabel.textContent =
      vehicleClassNames[Math.round(performance.classId)] ||
      `Class ${Math.round(performance.classId)}`;
    header.append(classLabel);
  }

  section.append(header);

  if (!performance.available) {
    const unavailable = document.createElement("div");
    unavailable.className = "performance-unavailable";

    const icon = document.createElement("span");
    icon.className = "performance-unavailable-icon";
    icon.setAttribute("aria-hidden", "true");

    const unavailableCopy = document.createElement("div");
    const unavailableTitle = document.createElement("strong");
    unavailableTitle.textContent = "Performance data unavailable";

    const unavailableDescription = document.createElement("p");
    unavailableDescription.textContent = performance.supported
      ? "Handling data could not be read for this model. A test drive is still available."
      : "This add-on does not expose model handling data. Try it on the road to learn its character.";

    unavailableCopy.append(unavailableTitle, unavailableDescription);
    unavailable.append(icon, unavailableCopy);
    section.append(unavailable);
    return section;
  }

  const metrics = document.createElement("div");
  metrics.className = "performance-metrics";
  const topSpeed = performance.topSpeedMph;
  metrics.append(
    createPerformanceMetric(
      "Estimated top speed",
      topSpeed === null ? "Not measured" : `~${Math.round(topSpeed)} mph`,
      performance.topSpeedRating,
    ),
    createPerformanceMetric(
      "Acceleration",
      performance.acceleration === null
        ? "Not measured"
        : `${Math.round(performance.acceleration)} / 100`,
      performance.acceleration,
    ),
    createPerformanceMetric(
      "Braking",
      performance.braking === null
        ? "Not measured"
        : `${Math.round(performance.braking)} / 100`,
      performance.braking,
    ),
    createPerformanceMetric(
      "Traction",
      performance.traction === null
        ? "Not measured"
        : `${Math.round(performance.traction)} / 100`,
      performance.traction,
    ),
  );
  section.append(metrics);
  return section;
}

function renderVehicleInfoEmpty() {
  const presentation =
    activeShop.presentation || normalizedShopPresentation({}, activeShop);
  vehicleInfo.replaceChildren();
  vehicleInfo.classList.add("is-empty");
  vehicleInfo.classList.remove("is-checkout", "is-processing");
  delete vehicleInfo.dataset.vehicleModel;
  delete vehicleInfo.dataset.vehicleSignature;
  vehicleInfo.setAttribute(
    "aria-label",
    `${presentation.eyebrow} showroom details`,
  );
  vehicleInfo.setAttribute("aria-hidden", "false");
  vehicleInfo.scrollTop = 0;

  const emptyState = document.createElement("div");
  emptyState.className = "detail-empty-state";

  const hero = document.createElement("div");
  hero.className = "detail-empty-hero";

  const image = document.createElement("img");
  image.alt = `${presentation.eyebrow} showroom`;
  image.decoding = "async";
  image.draggable = false;

  const fallbackPresentation =
    defaultShopPresentations[shopTypeKey(activeShop)];
  const imageCandidates = [
    presentation.image,
    fallbackPresentation.image,
    presentation.logo,
    fallbackPresentation.logo,
  ].filter(
    (candidate, index, candidates) =>
      candidate && candidates.indexOf(candidate) === index,
  );
  let imageCandidateIndex = 0;
  image.addEventListener("error", () => {
    imageCandidateIndex += 1;

    if (imageCandidates[imageCandidateIndex]) {
      image.src = imageCandidates[imageCandidateIndex];
      return;
    }

    hero.classList.add("is-missing");
    image.remove();
  });
  image.src = imageCandidates[imageCandidateIndex];

  const status = document.createElement("span");
  status.className = "shop-hero-status";
  status.setAttribute("aria-hidden", "true");
  status.textContent = "Showroom open";
  hero.append(image, status);

  const copy = document.createElement("div");
  copy.className = "detail-empty-copy";

  const eyebrow = document.createElement("span");
  eyebrow.className = "eyebrow";
  eyebrow.textContent = presentation.eyebrow;

  const title = document.createElement("h2");
  title.textContent = presentation.title;

  const description = document.createElement("p");
  description.textContent = presentation.description;
  copy.append(eyebrow, title, description);

  const details = document.createElement("div");
  details.className = "shop-detail-list";
  presentation.details.forEach((detail) => {
    const item = document.createElement("div");
    item.className = "shop-detail";

    const label = document.createElement("span");
    label.textContent = detail.label;
    const value = document.createElement("strong");
    value.textContent = detail.value;
    item.append(label, value);
    details.append(item);
  });

  emptyState.append(hero, copy, details);
  vehicleInfo.append(emptyState);
}

function updateSelectedCards(model) {
  vehicleGrid.querySelectorAll(".vehicle-card").forEach((card) => {
    const isSelected = card.dataset.model === model;
    card.classList.toggle("is-selected", isSelected);
    card.setAttribute("aria-pressed", String(isSelected));
  });
}

function checkoutOptionLabel(options, id, fallback = "Included") {
  return (
    options.find((option) => option.id === id)?.label ||
    checkoutText(id, fallback, 48)
  );
}

function setCheckoutVehicleContext(vehicle, label) {
  vehicleInfo.replaceChildren();
  vehicleInfo.classList.remove("is-empty");
  vehicleInfo.classList.add("is-checkout");
  vehicleInfo.classList.toggle("is-processing", checkoutBusy === "purchase");
  vehicleInfo.dataset.vehicleModel = vehicle.model;
  vehicleInfo.dataset.vehicleSignature = vehicleDetailSignature(vehicle);
  vehicleInfo.setAttribute("aria-label", label);
  vehicleInfo.setAttribute("aria-hidden", "false");
  updateSelectedCards(vehicle.model);
}

function createCheckoutHeader(vehicle, stage) {
  const header = document.createElement("header");
  header.className = "checkout-header";

  const navigation = document.createElement("div");
  navigation.className = "checkout-navigation";

  const back = document.createElement("button");
  back.type = "button";
  back.className = "checkout-back";
  back.setAttribute("aria-label", "Back to vehicle details");
  back.textContent = "Back";
  back.disabled = checkoutBusy === "purchase";
  back.addEventListener("click", returnToVehicleDetails);

  const progress = document.createElement("div");
  progress.className = "checkout-progress";
  progress.setAttribute("aria-label", "Checkout progress");

  [
    ["configure", "Configure"],
    ["review", "Review"],
  ].forEach(([step, label], index) => {
    const item = document.createElement("span");
    const isActive = step === stage || (stage === "processing" && step === "review");
    const isComplete = step === "configure" && stage !== "configure";
    item.classList.toggle("active", isActive);
    item.classList.toggle("complete", isComplete);
    item.setAttribute("aria-current", isActive ? "step" : "false");
    item.textContent = `${index + 1} ${label}`;
    progress.append(item);
  });

  navigation.append(back, progress);

  const vehicleSummary = document.createElement("div");
  vehicleSummary.className = "checkout-vehicle-summary";

  const image = document.createElement("div");
  image.className = "checkout-vehicle-image vehicle-media is-loading";
  image.setAttribute("role", "img");
  image.setAttribute("aria-label", vehicle.name);
  loadVehicleImage(image, vehicle, "high");

  const copy = document.createElement("div");
  copy.className = "checkout-vehicle-copy";
  const eyebrow = document.createElement("span");
  eyebrow.className = "eyebrow";
  eyebrow.textContent = vehicle.brand;
  const name = document.createElement("h2");
  name.textContent = vehicle.name;
  const price = document.createElement("strong");
  price.textContent = formatPrice(vehicle.price);
  copy.append(eyebrow, name, price);
  vehicleSummary.append(image, copy);
  header.append(navigation, vehicleSummary);
  return header;
}

function createCheckoutSection(title, description) {
  const section = document.createElement("section");
  section.className = "checkout-section";
  const heading = document.createElement("div");
  heading.className = "checkout-section-heading";
  const sectionTitle = document.createElement("h3");
  sectionTitle.textContent = title;
  const sectionDescription = document.createElement("p");
  sectionDescription.textContent = description;
  heading.append(sectionTitle, sectionDescription);
  section.append(heading);
  return section;
}

function checkoutSelectionChanged() {
  activeQuote = null;
  checkoutError = "";
  vehicleInfo.querySelector(".checkout-alert")?.replaceChildren();
}

function featuredColorOptions(options, selectedId) {
  const available = Array.isArray(options) ? options : [];
  const optionsById = new Map(available.map((option) => [option.id, option]));
  const featured = featuredColorIds
    .map((id) => optionsById.get(id))
    .filter(Boolean)
    .slice(0, featuredColorLimit);
  const selected = optionsById.get(selectedId);

  if (selected && !featured.some((option) => option.id === selected.id)) {
    if (featured.length >= featuredColorLimit) {
      featured[featured.length - 1] = selected;
    } else {
      featured.push(selected);
    }
  }

  for (const option of available) {
    if (featured.length >= featuredColorLimit) break;
    if (!featured.some((candidate) => candidate.id === option.id)) {
      featured.push(option);
    }
  }

  return featured.slice(0, featuredColorLimit);
}

function checkoutPlatePreviewText() {
  if (checkoutDraft?.plateMode === "prefix") {
    return `${checkoutDraft.platePrefix || "PDM"} ••••`;
  }

  return "PENDING";
}

function checkoutPlateStyle(styleId, options = checkoutConfig?.plateStyles) {
  const available = Array.isArray(options) ? options : [];
  const safeStyleId = safeCheckoutId(styleId);
  return available.find((option) => option.id === safeStyleId) || available[0] || null;
}

function updateLicensePlate(plate, number, styleId, options = checkoutConfig?.plateStyles) {
  const style = checkoutPlateStyle(styleId, options);
  const safeStyleId = style?.id || safeCheckoutId(styleId) || "blue_white";
  const safeNumber = checkoutText(number, "PENDING", 16).toLocaleUpperCase();
  const artwork = plate.querySelector(".checkout-license-plate-artwork");
  const image = style?.image && safePlateArtworkPattern.test(style.image)
    ? style.image
    : "";

  plate.dataset.plateStyle = safeStyleId;
  plate.dataset.hasArtwork = String(Boolean(image));
  plate.classList.toggle("is-compact", safeNumber.length > 8);
  if (artwork) {
    artwork.hidden = !image;
    if (image && artwork.getAttribute("src") !== image) artwork.src = image;
    if (!image) artwork.removeAttribute("src");
  }
  plate.querySelector(".checkout-license-plate-number").textContent = safeNumber;
  plate.setAttribute(
    "aria-label",
    `${style?.label || "San Andreas"} registration plate: ${safeNumber}`,
  );
}

function createLicensePlate(
  number,
  styleId,
  className = "",
  options = checkoutConfig?.plateStyles,
) {
  const plate = document.createElement("span");
  plate.className = `checkout-license-plate${className ? ` ${className}` : ""}`;

  const artwork = document.createElement("img");
  artwork.className = "checkout-license-plate-artwork";
  artwork.alt = "";
  artwork.decoding = "async";
  artwork.draggable = false;
  const jurisdiction = document.createElement("span");
  jurisdiction.className = "checkout-license-plate-jurisdiction";
  jurisdiction.textContent = "San Andreas";
  const registration = document.createElement("strong");
  registration.className = "checkout-license-plate-number";
  const region = document.createElement("span");
  region.className = "checkout-license-plate-region";
  region.textContent = "Los Santos • Blaine County";

  plate.append(artwork, jurisdiction, registration, region);
  updateLicensePlate(plate, number, styleId, options);
  return plate;
}

function createPlateStyleCarousel(options, getPlateNumber) {
  const available = Array.isArray(options) ? options : [];
  const carousel = document.createElement("div");
  carousel.className = "checkout-plate-carousel";
  carousel.setAttribute("role", "group");
  carousel.setAttribute("aria-roledescription", "carousel");
  carousel.setAttribute("aria-label", "Plate style");

  const stage = document.createElement("div");
  stage.className = "checkout-plate-carousel-stage";
  const previous = document.createElement("button");
  previous.type = "button";
  previous.className = "checkout-plate-carousel-previous";
  previous.setAttribute("aria-label", "Previous plate style");
  previous.title = "Previous plate style";
  previous.textContent = "‹";
  const plate = createLicensePlate(
    getPlateNumber(),
    checkoutDraft.plateStyleId,
    "",
    available,
  );
  plate.setAttribute("aria-hidden", "true");
  const next = document.createElement("button");
  next.type = "button";
  next.className = "checkout-plate-carousel-next";
  next.setAttribute("aria-label", "Next plate style");
  next.title = "Next plate style";
  next.textContent = "›";
  stage.append(previous, plate, next);

  const status = document.createElement("div");
  status.className = "checkout-plate-carousel-status";
  status.setAttribute("aria-live", "polite");
  status.setAttribute("aria-atomic", "true");
  const label = document.createElement("strong");
  const position = document.createElement("span");
  status.append(label, position);
  carousel.append(stage, status);

  const selectedIndex = () => {
    const index = available.findIndex(
      (option) => option.id === checkoutDraft.plateStyleId,
    );
    return index >= 0 ? index : 0;
  };
  const refresh = () => {
    const index = selectedIndex();
    const option = available[index];
    if (!option) return;

    checkoutDraft.plateStyleId = option.id;
    updateLicensePlate(plate, getPlateNumber(), option.id, available);
    label.textContent = option.label;
    position.textContent = `${index + 1} of ${available.length}`;
    carousel.setAttribute(
      "aria-label",
      `Plate style: ${option.label}, ${index + 1} of ${available.length}`,
    );
  };
  const move = (offset) => {
    if (available.length < 2) return;
    const index = (selectedIndex() + offset + available.length) % available.length;
    checkoutDraft.plateStyleId = available[index].id;
    checkoutSelectionChanged();
    refresh();
  };

  previous.disabled = available.length < 2;
  next.disabled = available.length < 2;
  previous.addEventListener("click", () => move(-1));
  next.addEventListener("click", () => move(1));
  carousel.addEventListener("keydown", (event) => {
    if (event.key !== "ArrowLeft" && event.key !== "ArrowRight") return;
    event.preventDefault();
    move(event.key === "ArrowLeft" ? -1 : 1);
  });
  refresh();

  return { element: carousel, refresh };
}

function createColorPicker(title, field, options) {
  const fieldset = document.createElement("fieldset");
  fieldset.className = "checkout-color-field";

  const legend = document.createElement("legend");
  legend.className = "sr-only";
  legend.textContent = title;
  const heading = document.createElement("div");
  heading.className = "checkout-option-heading";
  const visibleLabel = document.createElement("span");
  visibleLabel.className = "checkout-option-label";
  visibleLabel.textContent = title;
  const selectedLabel = document.createElement("span");
  selectedLabel.textContent = checkoutOptionLabel(options, checkoutDraft[field]);
  heading.append(visibleLabel, selectedLabel);

  const swatches = document.createElement("div");
  swatches.className = "checkout-swatches";
  swatches.setAttribute("role", "group");
  swatches.setAttribute("aria-label", `${title}: five featured finishes`);

  featuredColorOptions(options, checkoutDraft[field]).forEach((option) => {
    const button = document.createElement("button");
    button.type = "button";
    button.className = "checkout-swatch";
    button.dataset.checkoutValue = option.id;
    button.style.setProperty("--swatch-color", option.swatch);
    button.setAttribute("aria-label", `${title}: ${option.label}`);
    button.setAttribute(
      "aria-pressed",
      String(checkoutDraft[field] === option.id),
    );
    button.title = option.label;
    button.addEventListener("click", () => {
      checkoutDraft[field] = option.id;
      checkoutSelectionChanged();
      selectedLabel.textContent = option.label;
      swatches.querySelectorAll(".checkout-swatch").forEach((candidate) => {
        candidate.setAttribute(
          "aria-pressed",
          String(candidate.dataset.checkoutValue === option.id),
        );
      });
    });
    swatches.append(button);
  });

  fieldset.append(legend, heading, swatches);
  return fieldset;
}

function createChoiceGroup({ label, field, options, className, onChange }) {
  const fieldset = document.createElement("fieldset");
  fieldset.className = className;
  const legend = document.createElement("legend");
  legend.className = "sr-only";
  legend.textContent = label;
  const group = document.createElement("div");
  group.className = `${className}-options`;

  options.forEach((option) => {
    const button = document.createElement("button");
    button.type = "button";
    button.dataset.checkoutValue = option.id;
    button.setAttribute("aria-pressed", String(checkoutDraft[field] === option.id));

    const optionLabel = document.createElement("strong");
    optionLabel.textContent = option.label;
    button.append(optionLabel);

    if (option.description) {
      const description = document.createElement("span");
      description.textContent = option.description;
      button.append(description);
    }

    if (option.preview) {
      const preview = createLicensePlate(
        "SAMPLE",
        option.id,
        "checkout-plate-style-preview",
      );
      preview.setAttribute("aria-hidden", "true");
      button.prepend(preview);
    }

    button.addEventListener("click", () => {
      checkoutDraft[field] = option.id;
      checkoutSelectionChanged();
      group.querySelectorAll("button").forEach((candidate) => {
        candidate.setAttribute(
          "aria-pressed",
          String(candidate.dataset.checkoutValue === option.id),
        );
      });
      onChange?.(option.id);
    });
    group.append(button);
  });

  fieldset.append(legend, group);
  return fieldset;
}

function createCheckoutAlert() {
  const alert = document.createElement("div");
  alert.className = `checkout-alert${checkoutError ? " has-message" : ""}`;
  alert.setAttribute("role", "alert");
  alert.setAttribute("aria-live", "assertive");
  if (checkoutError) alert.textContent = checkoutError;
  return alert;
}

function checkoutPayload() {
  const capabilities = checkoutConfig.capabilities;
  return {
    primaryColorId: capabilities.colors ? checkoutDraft.primaryColorId : null,
    secondaryColorId: capabilities.colors && capabilities.secondaryColor
      ? checkoutDraft.secondaryColorId
      : null,
    plateMode: checkoutDraft.plateMode,
    platePrefix:
      checkoutDraft.plateMode === "prefix" ? checkoutDraft.platePrefix : "",
    plateStyleId: capabilities.plateStyles ? checkoutDraft.plateStyleId : null,
    deliveryMode: capabilities.delivery ? checkoutDraft.deliveryMode : null,
  };
}

function validateCheckoutDraft() {
  const config = checkoutConfig;
  if (!config.colors.some((option) => option.id === checkoutDraft.primaryColorId)) {
    return "Choose a valid primary finish.";
  }
  if (!config.colors.some((option) => option.id === checkoutDraft.secondaryColorId)) {
    return "Choose a valid secondary finish.";
  }
  if (
    checkoutDraft.plateMode === "prefix" &&
    !/^[A-Z0-9]{1,3}$/.test(checkoutDraft.platePrefix)
  ) {
    return "Enter one to three letters or numbers for the plate prefix.";
  }
  if (
    !config.plateStyles.some(
      (option) => option.id === checkoutDraft.plateStyleId,
    )
  ) {
    return "Choose a valid plate style.";
  }
  if (
    !config.deliveryModes.some(
      (option) => option.id === checkoutDraft.deliveryMode,
    )
  ) {
    return "Choose a valid delivery method.";
  }
  return null;
}

function renderCheckoutConfigure(vehicle) {
  checkoutStage = "configure";
  setCheckoutVehicleContext(vehicle, `Configure ${vehicle.name}`);

  const form = document.createElement("form");
  form.className = "checkout-shell";
  form.noValidate = true;
  form.append(createCheckoutHeader(vehicle, "configure"));

  const scroll = document.createElement("div");
  scroll.className = "checkout-scroll";

  const intro = document.createElement("div");
  intro.className = "checkout-intro";
  const eyebrow = document.createElement("span");
  eyebrow.className = "eyebrow";
  eyebrow.textContent = "Factory order";
  const title = document.createElement("h3");
  title.textContent = "Make it yours";
  const description = document.createElement("p");
  description.textContent =
    "Choose the factory options for your vehicle, then request a secure final quote.";
  intro.append(eyebrow, title, description);
  scroll.append(intro);

  const config = checkoutConfig;
  if (config.capabilities.colors || config.capabilities.secondaryColor) {
    const paint = createCheckoutSection(
      "Exterior finish",
      "Named factory finishes are applied when your vehicle is delivered.",
    );
    paint.append(createColorPicker("Primary", "primaryColorId", config.colors));
    if (config.capabilities.secondaryColor) {
      paint.append(
        createColorPicker("Secondary", "secondaryColorId", config.colors),
      );
    }
    scroll.append(paint);
  }

  if (config.capabilities.platePrefix || config.capabilities.plateStyles) {
    const registration = createCheckoutSection(
      "Registration",
      "Your final plate remains unique and is issued by the dealership.",
    );
    let refreshRegistrationPreview;
    if (config.capabilities.plateStyles) {
      const plateCarousel = createPlateStyleCarousel(
        config.plateStyles,
        checkoutPlatePreviewText,
      );
      refreshRegistrationPreview = plateCarousel.refresh;
      registration.append(plateCarousel.element);
    } else {
      const registrationPreview = document.createElement("div");
      registrationPreview.className = "checkout-registration-preview";
      registrationPreview.setAttribute("role", "img");
      const livePlate = createLicensePlate(
        checkoutPlatePreviewText(),
        checkoutDraft.plateStyleId,
      );
      livePlate.setAttribute("aria-hidden", "true");
      const registrationPreviewLabel = document.createElement("span");
      registrationPreviewLabel.textContent = "San Andreas registration preview";
      registrationPreview.append(livePlate, registrationPreviewLabel);
      registration.append(registrationPreview);

      refreshRegistrationPreview = () => {
        const previewText = checkoutPlatePreviewText();
        updateLicensePlate(
          livePlate,
          previewText,
          checkoutDraft.plateStyleId,
        );
        registrationPreview.setAttribute(
          "aria-label",
          `San Andreas registration preview: ${previewText}`,
        );
      };
    }
    refreshRegistrationPreview();

    if (config.capabilities.platePrefix) {
      const modeGroup = createChoiceGroup({
        label: "Plate number",
        field: "plateMode",
        className: "checkout-segments",
        options: [
          { id: "standard", label: "Standard" },
          { id: "prefix", label: "Custom prefix" },
        ],
        onChange: (mode) => {
          prefixField.hidden = mode !== "prefix";
          refreshRegistrationPreview();
          if (mode === "prefix") prefixInput.focus();
        },
      });
      registration.append(modeGroup);

      const prefixField = document.createElement("div");
      prefixField.className = "checkout-prefix-field";
      prefixField.hidden = checkoutDraft.plateMode !== "prefix";
      const prefixLabel = document.createElement("label");
      prefixLabel.htmlFor = "checkoutPlatePrefix";
      prefixLabel.textContent = "Prefix";
      const prefixControl = document.createElement("div");
      prefixControl.className = "checkout-prefix-control";
      const prefixInput = document.createElement("input");
      prefixInput.id = "checkoutPlatePrefix";
      prefixInput.type = "text";
      prefixInput.inputMode = "text";
      prefixInput.autocomplete = "off";
      prefixInput.spellcheck = false;
      prefixInput.maxLength = 3;
      prefixInput.placeholder = "PDM";
      prefixInput.value = checkoutDraft.platePrefix;
      prefixInput.setAttribute("aria-describedby", "checkoutPrefixHelp");
      const suffix = document.createElement("span");
      suffix.setAttribute("aria-hidden", "true");
      suffix.textContent = "••••";
      prefixControl.append(prefixInput, suffix);
      const prefixHelp = document.createElement("p");
      prefixHelp.id = "checkoutPrefixHelp";
      prefixHelp.textContent = "1–3 letters or numbers. The suffix is generated securely.";
      prefixInput.addEventListener("input", () => {
        const normalized = prefixInput.value
          .toLocaleUpperCase()
          .replace(/[^A-Z0-9]/g, "")
          .slice(0, 3);
        prefixInput.value = normalized;
        checkoutDraft.platePrefix = normalized;
        checkoutSelectionChanged();
        refreshRegistrationPreview();
      });
      prefixField.append(prefixLabel, prefixControl, prefixHelp);
      registration.append(prefixField);
    }

    scroll.append(registration);
  }

  if (config.capabilities.delivery) {
    const delivery = createCheckoutSection(
      "Delivery",
      "Choose where you want the dealership to hand off your purchase.",
    );
    delivery.append(
      createChoiceGroup({
        label: "Delivery method",
        field: "deliveryMode",
        className: "checkout-delivery-choices",
        options: config.deliveryModes,
      }),
    );
    scroll.append(delivery);
  }

  const footer = document.createElement("footer");
  footer.className = "checkout-footer";
  const alert = createCheckoutAlert();
  const actions = document.createElement("div");
  actions.className = "checkout-footer-actions";
  const cancel = document.createElement("button");
  cancel.type = "button";
  cancel.className = "checkout-secondary-action";
  cancel.textContent = "Back";
  cancel.addEventListener("click", returnToVehicleDetails);
  const review = document.createElement("button");
  review.type = "submit";
  review.className = "checkout-primary-action";
  review.disabled = checkoutBusy === "quote";
  review.textContent =
    checkoutBusy === "quote" ? "Building quote…" : "Review order";
  actions.append(cancel, review);
  footer.append(alert, actions);
  form.append(scroll, footer);
  form.addEventListener("submit", (event) => {
    event.preventDefault();
    requestVehicleQuote(vehicle);
  });
  vehicleInfo.append(form);
}

function quoteCost(value, fallback = 0) {
  const cost = finiteNumber(value);
  return cost !== null && cost >= 0 && Number.isSafeInteger(Math.round(cost))
    ? Math.round(cost)
    : Math.max(0, Math.round(fallback));
}

function normalizedQuote(value, vehicle) {
  const raw = asObject(value);
  const id = asText(raw.id)
    .replace(/[\u0000-\u001f\u007f]+/g, "")
    .trim()
    .slice(0, 128);
  if (!/^[A-Za-z0-9._:-]+$/.test(id)) return null;

  const quotedModel = storageIdentifier(raw.model, maxStoredModelLength);
  const expectedModel = storageIdentifier(vehicle.model, maxStoredModelLength);
  if (quotedModel && quotedModel !== expectedModel) return null;

  const rawOptions = asObject(raw.options);
  const primaryColors = normalizedCheckoutOptions(
    rawOptions.primaryColors || rawOptions.colors,
    "color",
    checkoutConfig.colors,
    24,
  );
  const secondaryColors = normalizedCheckoutOptions(
    rawOptions.secondaryColors || rawOptions.colors,
    "color",
    primaryColors,
    24,
  );
  const plateStyles = normalizedCheckoutOptions(
    rawOptions.plateStyles,
    "plate",
    checkoutConfig.plateStyles,
    8,
  );
  const deliveryModes = normalizedCheckoutOptions(
    rawOptions.deliveryModes,
    "delivery",
    checkoutConfig.deliveryModes,
    2,
  );

  const rawSelection = asObject(raw.selection);
  const primaryColorId =
    safeCheckoutId(rawSelection.primaryColorId) || checkoutDraft.primaryColorId;
  const secondaryColorId =
    safeCheckoutId(rawSelection.secondaryColorId) ||
    checkoutDraft.secondaryColorId;
  const plateStyleId =
    safeCheckoutId(rawSelection.plateStyleId) || checkoutDraft.plateStyleId;
  const deliveryMode =
    rawSelection.deliveryMode === "garage" ||
    rawSelection.deliveryMode === "driveaway"
      ? rawSelection.deliveryMode
      : checkoutDraft.deliveryMode;
  const plateMode =
    rawSelection.plateMode === "prefix" ? "prefix" : "standard";
  const platePrefix = asText(rawSelection.platePrefix)
    .toLocaleUpperCase()
    .replace(/[^A-Z0-9]/g, "")
    .slice(0, 3);

  const rawCosts = asObject(raw.costs);
  const hasTotal = finiteNumber(rawCosts.total) !== null;
  if (!hasTotal) return null;
  const base = quoteCost(rawCosts.base, vehicle.price);
  const paint = quoteCost(rawCosts.paint);
  const plate = quoteCost(rawCosts.plate);
  const style = quoteCost(rawCosts.style);
  const total = quoteCost(rawCosts.total);

  const rawLabels = asObject(raw.labels);
  const labels = {};
  [
    "primaryColor",
    "secondaryColor",
    "plate",
    "plateMode",
    "plateStyle",
    "deliveryMode",
    "delivery",
  ].forEach((key) => {
    if (rawLabels[key] !== undefined) {
      labels[key] = checkoutText(rawLabels[key], "", 72);
    }
  });

  const rawCapabilities = asObject(raw.capabilities);
  const capabilities = {
    colors: booleanCapability(
      rawCapabilities.colors,
      checkoutConfig.capabilities.colors,
    ),
    secondaryColor: booleanCapability(
      rawCapabilities.secondaryColor,
      checkoutConfig.capabilities.secondaryColor,
    ),
    platePrefix: booleanCapability(
      rawCapabilities.platePrefix,
      checkoutConfig.capabilities.platePrefix,
    ),
    plateStyles: booleanCapability(
      rawCapabilities.plateStyles,
      checkoutConfig.capabilities.plateStyles,
    ),
    delivery: booleanCapability(
      rawCapabilities.delivery,
      checkoutConfig.capabilities.delivery,
    ),
  };

  const platePreview = checkoutText(
    raw.platePreview,
    plateMode === "prefix" && platePrefix
      ? `${platePrefix} ••••`
      : "Assigned at purchase",
    16,
  );

  return {
    id,
    expiresAt: raw.expiresAt,
    model: vehicle.model,
    shopId: safeCheckoutId(raw.shopId),
    vehicleType: checkoutText(raw.vehicleType, activeShop.type, 24),
    capabilities,
    options: { primaryColors, secondaryColors, plateStyles, deliveryModes },
    selection: {
      primaryColorId,
      secondaryColorId,
      plateMode,
      platePrefix,
      plateStyleId,
      deliveryMode,
    },
    labels,
    costs: { base, paint, plate, style, total },
    platePreview,
  };
}

function quoteExpiryText(value) {
  let date = null;
  const numeric = finiteNumber(value);
  if (numeric !== null) {
    date = new Date(numeric < 100000000000 ? numeric * 1000 : numeric);
  } else if (typeof value === "string") {
    const timestamp = Date.parse(value);
    if (Number.isFinite(timestamp)) date = new Date(timestamp);
  }

  if (!date || Number.isNaN(date.getTime())) return "Secure server quote";
  return `Reserved until ${date.toLocaleTimeString([], {
    hour: "numeric",
    minute: "2-digit",
  })}`;
}

function createReviewRow(label, value) {
  const row = document.createElement("div");
  row.className = "checkout-review-row";
  const rowLabel = document.createElement("span");
  rowLabel.textContent = label;
  const rowValue = document.createElement("strong");
  rowValue.textContent = value;
  row.append(rowLabel, rowValue);
  return row;
}

function renderCheckoutReview(vehicle) {
  if (!activeQuote) {
    renderCheckoutConfigure(vehicle);
    return;
  }

  checkoutStage = checkoutBusy === "purchase" ? "processing" : "review";
  setCheckoutVehicleContext(vehicle, `Review ${vehicle.name} order`);
  const quote = activeQuote;

  const shell = document.createElement("div");
  shell.className = "checkout-shell";
  shell.append(createCheckoutHeader(vehicle, checkoutStage));

  const scroll = document.createElement("div");
  scroll.className = "checkout-scroll";

  const intro = document.createElement("div");
  intro.className = "checkout-intro checkout-review-intro";
  const eyebrow = document.createElement("span");
  eyebrow.className = "eyebrow";
  eyebrow.textContent = "Order review";
  const title = document.createElement("h3");
  title.textContent = checkoutBusy === "purchase" ? "Processing order" : "Ready to order";
  const description = document.createElement("p");
  description.textContent =
    checkoutBusy === "purchase"
      ? "Keep the showroom open while the dealership confirms payment and delivery."
      : quoteExpiryText(quote.expiresAt);
  intro.append(eyebrow, title, description);
  scroll.append(intro);

  const registration = document.createElement("section");
  registration.className = "checkout-plate-preview";
  registration.setAttribute(
    "aria-label",
    `Registration preview: ${quote.platePreview}`,
  );
  const plate = createLicensePlate(
    quote.platePreview,
    quote.selection.plateStyleId,
    "",
    quote.options.plateStyles,
  );
  plate.setAttribute("aria-hidden", "true");
  const plateCaption = document.createElement("span");
  plateCaption.className = "checkout-plate-caption";
  plateCaption.textContent =
    quote.labels.plateStyle ||
    checkoutOptionLabel(
      quote.options.plateStyles,
      quote.selection.plateStyleId,
      "Standard plate",
    );
  registration.append(plate, plateCaption);
  scroll.append(registration);

  const configuration = createCheckoutSection(
    "Your configuration",
    "These server-approved choices will be saved with the vehicle.",
  );
  const selectedPrimary =
    quote.labels.primaryColor ||
    checkoutOptionLabel(
      quote.options.primaryColors,
      quote.selection.primaryColorId,
      "Factory finish",
    );
  configuration.append(createReviewRow("Primary finish", selectedPrimary));
  if (quote.capabilities.secondaryColor) {
    const selectedSecondary =
      quote.labels.secondaryColor ||
      checkoutOptionLabel(
        quote.options.secondaryColors,
        quote.selection.secondaryColorId,
        "Factory finish",
      );
    configuration.append(
      createReviewRow("Secondary finish", selectedSecondary),
    );
  }
  configuration.append(
    createReviewRow(
      "Registration",
      quote.labels.plate ||
        quote.labels.plateMode ||
        (quote.selection.plateMode === "prefix"
          ? `${quote.selection.platePrefix} prefix`
          : "Standard issue"),
    ),
  );
  configuration.append(
    createReviewRow(
      "Delivery",
      quote.labels.deliveryMode ||
        quote.labels.delivery ||
        checkoutOptionLabel(
          quote.options.deliveryModes,
          quote.selection.deliveryMode,
          quote.selection.deliveryMode === "garage"
            ? "Store in garage"
            : "Drive away",
        ),
    ),
  );
  scroll.append(configuration);

  const pricing = createCheckoutSection(
    "Price summary",
    "Every amount below was calculated and verified by the server.",
  );
  const costList = document.createElement("div");
  costList.className = "checkout-cost-list";
  [
    ["Vehicle", quote.costs.base],
    ["Paint options", quote.costs.paint],
    ["Registration", quote.costs.plate],
    ["Plate style", quote.costs.style],
  ].forEach(([label, value]) => {
    costList.append(createReviewRow(label, formatPrice(value)));
  });
  const total = createReviewRow("Total", formatPrice(quote.costs.total));
  total.classList.add("checkout-total-row");
  costList.append(total);
  pricing.append(costList);
  scroll.append(pricing);

  if (checkoutBusy === "purchase") {
    const processing = document.createElement("div");
    processing.className = "checkout-processing";
    processing.setAttribute("role", "status");
    const spinner = document.createElement("span");
    spinner.setAttribute("aria-hidden", "true");
    const processingCopy = document.createElement("div");
    const processingTitle = document.createElement("strong");
    processingTitle.textContent = "Confirming your order";
    const processingDescription = document.createElement("p");
    processingDescription.textContent =
      "Please wait. Do not close the showroom or submit the purchase again.";
    processingCopy.append(processingTitle, processingDescription);
    processing.append(spinner, processingCopy);
    scroll.append(processing);
  }

  const footer = document.createElement("footer");
  footer.className = "checkout-footer";
  const alert = createCheckoutAlert();
  const actions = document.createElement("div");
  actions.className = "checkout-footer-actions";
  const back = document.createElement("button");
  back.type = "button";
  back.className = "checkout-secondary-action";
  back.textContent = "Edit options";
  back.disabled = checkoutBusy === "purchase";
  back.addEventListener("click", () => {
    checkoutBusy = null;
    checkoutError = "";
    renderCheckoutConfigure(vehicle);
  });
  const purchase = document.createElement("button");
  purchase.type = "button";
  purchase.className = "checkout-primary-action";
  purchase.disabled = checkoutBusy === "purchase";
  purchase.textContent =
    checkoutBusy === "purchase"
      ? "Processing…"
      : `Purchase ${formatPrice(quote.costs.total)}`;
  purchase.addEventListener("click", () => confirmVehiclePurchase(vehicle));
  actions.append(back, purchase);
  footer.append(alert, actions);
  shell.append(scroll, footer);
  vehicleInfo.append(shell);
}

async function requestVehicleQuote(vehicle) {
  if (checkoutBusy || checkoutStage !== "configure") return;
  const validationError = validateCheckoutDraft();
  if (validationError) {
    checkoutError = validationError;
    renderCheckoutConfigure(vehicle);
    return;
  }

  checkoutBusy = "quote";
  checkoutError = "";
  const requestToken = ++checkoutRequestToken;
  renderCheckoutConfigure(vehicle);
  const response = await postNui("quoteVehicle", {
    model: vehicle.model,
    customization: checkoutPayload(),
  });

  if (
    requestToken !== checkoutRequestToken ||
    selectedVehicle?.model !== vehicle.model ||
    !isShopVisible()
  ) {
    return;
  }

  checkoutBusy = null;
  const result = asObject(response);
  if (result.ok !== true) {
    checkoutError = checkoutText(
      result.message,
      "The dealership could not build a quote. Check your options and try again.",
      180,
    );
    renderCheckoutConfigure(vehicle);
    return;
  }

  const quote = normalizedQuote(result.quote, vehicle);
  if (!quote) {
    checkoutError = "The dealership returned an invalid quote. Please try again.";
    renderCheckoutConfigure(vehicle);
    return;
  }

  activeQuote = quote;
  checkoutDraft = { ...quote.selection };
  checkoutError = "";
  renderCheckoutReview(vehicle);
}

async function confirmVehiclePurchase(vehicle) {
  if (checkoutBusy || !activeQuote) return;
  checkoutBusy = "purchase";
  checkoutError = "";
  const quoteId = activeQuote.id;
  const requestToken = ++checkoutRequestToken;
  renderCheckoutReview(vehicle);

  const response = await postNui("buyVehicle", {
    model: vehicle.model,
    quoteId,
  });

  if (requestToken !== checkoutRequestToken) return;
  checkoutBusy = null;
  const result = asObject(response);
  if (result.ok === true) {
    rememberRecentVehicle(vehicle.model);
    setShopVisible(false);
    closeVehicleInfo(false);
    removeDealerForm();
    return;
  }

  const code = asText(result.code).toLocaleLowerCase();
  checkoutError = checkoutText(
    result.message,
    "The purchase could not be completed. Your order was not submitted again.",
    180,
  );

  const quoteMustRefresh = new Set([
    "invalid_quote",
    "quote_required",
    "quote_expired",
    "quote_not_owned",
    "quote_mismatch",
    "quote_changed",
    "quote_retry",
  ]).has(code);

  if (quoteMustRefresh) {
    activeQuote = null;
    renderCheckoutConfigure(vehicle);
    return;
  }

  renderCheckoutReview(vehicle);
}

function openVehicleCheckout(vehicle) {
  if (!checkoutConfig?.enabled) {
    checkoutError = "Factory ordering is not available at this showroom.";
    return;
  }

  rememberRecentVehicle(vehicle.model);
  checkoutStage = "configure";
  checkoutDraft = newCheckoutDraft();
  activeQuote = null;
  checkoutBusy = null;
  checkoutError = "";
  renderCheckoutConfigure(vehicle);
}

function returnToVehicleDetails() {
  if (checkoutBusy === "purchase" || !selectedVehicle) return;
  const vehicle = selectedVehicle;
  checkoutRequestToken += 1;
  showVehicleInfo(vehicle);
}

function showVehicleInfo(vehicle) {
  resetCheckoutState();
  selectedVehicle = vehicle;
  vehicleInfo.replaceChildren();
  vehicleInfo.classList.remove("is-empty");
  vehicleInfo.dataset.vehicleModel = vehicle.model;
  vehicleInfo.dataset.vehicleSignature = vehicleDetailSignature(vehicle);
  vehicleInfo.setAttribute("aria-label", `${vehicle.name} details`);
  vehicleInfo.setAttribute("aria-hidden", "false");
  vehicleInfo.scrollTop = 0;
  updateSelectedCards(vehicle.model);

  const close = document.createElement("button");
  close.type = "button";
  close.className = "close-btn";
  close.setAttribute("aria-label", "Clear vehicle selection");
  close.textContent = "\u00d7";
  close.addEventListener("click", () => closeVehicleInfo(true));

  const hero = document.createElement("div");
  hero.className = "detail-hero";

  const image = document.createElement("div");
  image.className = "vehicle-media is-loading";
  image.setAttribute("role", "img");
  image.setAttribute("aria-label", vehicle.name);
  loadVehicleImage(image, vehicle, "high");

  const availability = document.createElement("span");
  availability.className = "detail-availability";
  availability.textContent = "In stock";
  hero.append(image, availability);

  const heading = document.createElement("div");
  heading.className = "detail-heading";
  heading.append(createBrandLogo(vehicle.brand, "brand-logo"));

  const headingCopy = document.createElement("div");
  headingCopy.className = "detail-title-copy";

  const eyebrow = document.createElement("span");
  eyebrow.className = "eyebrow";
  eyebrow.textContent = vehicle.brand;

  const name = document.createElement("h2");
  name.className = "vehicle-name";
  name.textContent = vehicle.name;
  headingCopy.append(eyebrow, name);
  heading.append(headingCopy);

  const purchaseSummary = document.createElement("div");
  purchaseSummary.className = "purchase-summary";
  const purchaseCopy = document.createElement("span");
  purchaseCopy.textContent = "Showroom price";
  const purchasePrice = document.createElement("strong");
  purchasePrice.textContent = formatPrice(vehicle.price);
  purchaseSummary.append(purchaseCopy, purchasePrice);

  const details = document.createElement("div");
  details.className = "vehicle-details";
  details.append(
    createStat(
      "Category",
      asText(categories[vehicle.category], vehicle.category || "Unknown"),
    ),
    createStat("Model", vehicle.model),
  );

  const actions = document.createElement("div");
  actions.className = "vehicle-actions";

  const testDriveButton = document.createElement("button");
  testDriveButton.type = "button";
  testDriveButton.className = "test-drive-btn";
  testDriveButton.textContent = "Test drive";
  testDriveButton.disabled = inTestDrive;
  testDriveButton.addEventListener("click", () => startTestDrive(vehicle.model));

  const buyButton = document.createElement("button");
  buyButton.type = "button";
  buyButton.className = "buy-btn";
  buyButton.textContent = "Configure & purchase";
  buyButton.disabled = checkoutConfig?.enabled === false;
  buyButton.addEventListener("click", () => openVehicleCheckout(vehicle));

  actions.append(testDriveButton, buyButton);
  vehicleInfo.append(
    close,
    hero,
    heading,
    purchaseSummary,
    details,
    createPerformanceSection(vehicle.performance),
    actions,
  );
}

function closeVehicleInfo(restoreFocus = true) {
  resetCheckoutState();
  selectedVehicle = null;
  updateSelectedCards(null);
  renderVehicleInfoEmpty();

  if (restoreFocus && lastFocusedCard?.isConnected) {
    lastFocusedCard.focus({ preventScroll: true });
  }

  if (!restoreFocus || !lastFocusedCard?.isConnected) {
    lastFocusedCard = null;
  }
}

function startTestDrive(model) {
  if (inTestDrive) return;

  rememberRecentVehicle(model);
  inTestDrive = true;
  showTestDriveTimer(true);
  postNui("testDrive", { model });
  setShopVisible(false);
  closeVehicleInfo(false);
}

function buyVehicle(model) {
  const vehicle =
    selectedVehicle?.model === model
      ? selectedVehicle
      : allVehiclesForCategory("all").find(
          (candidate) => candidate.model === model,
        );
  if (vehicle) openVehicleCheckout(vehicle);
}

function resetCatalogueControls(categoryKey) {
  currentCategory = categoryHasInventory(categoryKey)
    ? normalizedCategoryKey(categoryKey)
    : openingCategory();
  currentBrand = null;
  currentSort = "name";
  sortOrder = "asc";
  searchInput.value = "";
  sortSelect.value = "name-asc";
  brandSelect.value = "";
}

function shopPresentation(shop) {
  const type = asText(shop.type, "car").toLocaleLowerCase();
  const presentations = {
    boat: {
      eyebrow: "Marine showroom",
      subtitle: "Browse the current marine inventory",
      inventoryTitle: "Marine inventory",
      inventoryDescription: "Select a vessel to view its purchase options.",
    },
    air: {
      eyebrow: "Aviation showroom",
      subtitle: "Browse the current aircraft inventory",
      inventoryTitle: "Aircraft inventory",
      inventoryDescription: "Select an aircraft to view its purchase options.",
    },
    car: {
      eyebrow: "Vehicle showroom",
      subtitle: "Browse the current vehicle inventory",
      inventoryTitle: "Vehicle inventory",
      inventoryDescription: "Select a vehicle to view its purchase options.",
    },
  };

  return presentations[type] || presentations.car;
}

function updateShopBranding(shopData) {
  const shop = {
    id: asText(shopData.id, "auto"),
    label: asText(shopData.label, "Vehicle Shop"),
    type: asText(shopData.type, "car"),
  };
  const categoryOrder = normalizedCategoryOrder(shopData.categoryOrder);
  const requestedDefault = normalizedCategoryKey(shopData.defaultCategory);
  const defaultCategory = categoryHasInventory(requestedDefault)
    ? requestedDefault
    : categoryOrder[0] || "all";
  activeShop = {
    ...shop,
    defaultCategory,
    categoryOrder,
    presentation: normalizedShopPresentation(shopData.presentation, shop),
  };

  const presentation = shopPresentation(activeShop);
  document.title = activeShop.label;
  document.getElementById("shopTitle").textContent = activeShop.label;
  document.getElementById("shopSubtitle").textContent = presentation.subtitle;
  document.getElementById("inventoryTitle").textContent =
    presentation.inventoryTitle;
  document.getElementById("inventoryDescription").textContent =
    presentation.inventoryDescription;
  document.querySelector(".showroom-header .eyebrow").textContent =
    presentation.eyebrow;
  vehicleGrid.setAttribute("aria-label", presentation.inventoryTitle);
}

function removeDealerForm() {
  container.classList.remove("dealer-mode");
  container.querySelector(".dealer-form")?.remove();
}

function closeShop() {
  if (!isShopVisible()) return;
  setShopVisible(false);
  closeVehicleInfo(false);
  removeDealerForm();
  postNui("close");
}

function createDealerField({ id, label, type = "text", fullWidth = false }) {
  const field = document.createElement("div");
  field.className = `dealer-field${fullWidth ? " full-width" : ""}`;

  const fieldLabel = document.createElement("label");
  fieldLabel.htmlFor = id;
  fieldLabel.textContent = label;

  const input = document.createElement("input");
  input.id = id;
  input.name = id;
  input.type = type;
  input.required = true;
  input.autocomplete = "off";
  if (type === "number") input.min = "1";

  field.append(fieldLabel, input);
  return { field, input };
}

function openDealerMenu(dealerCategories) {
  removeDealerForm();
  setShopVisible(true);
  container.classList.add("dealer-mode");

  const panel = document.createElement("section");
  panel.className = "dealer-form";
  panel.setAttribute("aria-labelledby", "dealerFormTitle");

  const header = document.createElement("header");
  header.className = "dealer-header";

  const headerIcon = document.createElement("span");
  headerIcon.className = "dealer-header-icon";
  headerIcon.setAttribute("aria-hidden", "true");

  const headerCopy = document.createElement("div");
  const headerEyebrow = document.createElement("span");
  headerEyebrow.className = "eyebrow";
  headerEyebrow.textContent = "Dealer tools";
  const title = document.createElement("h2");
  title.id = "dealerFormTitle";
  title.textContent = "Add vehicle to stock";
  const description = document.createElement("p");
  description.textContent = "Submit a catalogue entry for server validation.";
  headerCopy.append(headerEyebrow, title, description);
  header.append(headerIcon, headerCopy);

  const form = document.createElement("form");
  form.id = "addVehicleForm";

  const nameField = createDealerField({ id: "vehicleName", label: "Vehicle name" });
  const modelField = createDealerField({ id: "vehicleModel", label: "Spawn code" });
  const priceField = createDealerField({ id: "vehiclePrice", label: "Price", type: "number" });
  const brandField = createDealerField({ id: "vehicleBrand", label: "Brand" });

  const categoryField = document.createElement("div");
  categoryField.className = "dealer-field full-width";
  const categoryLabel = document.createElement("label");
  categoryLabel.htmlFor = "vehicleCategory";
  categoryLabel.textContent = "Category";
  const categoryWrap = document.createElement("div");
  categoryWrap.className = "dealer-select-wrap sort-container";
  const categorySelect = document.createElement("select");
  categorySelect.id = "vehicleCategory";
  categorySelect.required = true;
  const placeholder = document.createElement("option");
  placeholder.value = "";
  placeholder.textContent = "Select category";
  categorySelect.append(placeholder);
  Object.entries(asObject(dealerCategories)).forEach(([key, label]) => {
    const option = document.createElement("option");
    option.value = key;
    option.textContent = asText(label, key);
    categorySelect.append(option);
  });
  categoryWrap.append(categorySelect);
  categoryField.append(categoryLabel, categoryWrap);

  const actions = document.createElement("div");
  actions.className = "dealer-actions";
  const feedback = document.createElement("span");
  feedback.className = "dealer-feedback";
  feedback.setAttribute("role", "status");
  const submit = document.createElement("button");
  submit.type = "submit";
  submit.className = "dealer-submit";
  submit.textContent = "Add to stock";
  actions.append(feedback, submit);

  form.append(
    nameField.field,
    modelField.field,
    priceField.field,
    brandField.field,
    categoryField,
    actions,
  );

  form.addEventListener("submit", (event) => {
    event.preventDefault();
    submit.disabled = true;
    feedback.className = "dealer-feedback";
    feedback.textContent = "Submitting…";

    postNui("addVehicle", {
      name: nameField.input.value.trim(),
      model: modelField.input.value.trim(),
      price: Number.parseInt(priceField.input.value, 10),
      brand: brandField.input.value.trim(),
      category: categorySelect.value,
    }).finally(() => {
      feedback.className = "dealer-feedback success";
      feedback.textContent = "Submitted for validation";
      submit.disabled = false;
      form.reset();
    });
  });

  panel.append(header, form);
  container.append(panel);
  nameField.input.focus();
}

function handleOpen(data) {
  categories = asObject(data.categories);
  vehicles = asObject(data.vehicles);
  checkoutConfig = normalizedCheckoutConfig(data.checkout);
  resetCheckoutState();
  selectedVehicle = null;
  lastFocusedCard = null;
  removeDealerForm();
  updateShopBranding(asObject(data.shop));
  resetCatalogueControls(activeShop.defaultCategory);
  setupBrandOptions();
  inTestDrive = false;
  showTestDriveTimer(false);
  const recentVehicle = restoreRecentVehicle();
  if (recentVehicle && categoryHasInventory(recentVehicle.category)) {
    currentCategory = recentVehicle.category;
  }
  selectedVehicle = recentVehicle;
  setupCategories();
  setShopVisible(true);
  renderVehicles();
  if (recentVehicle) scrollVehicleCardIntoView(recentVehicle.model);
}

function bindListeners() {
  searchInput.addEventListener("input", () => {
    window.clearTimeout(searchDebounce);
    searchDebounce = window.setTimeout(renderVehicles, 150);
  });

  sortSelect.addEventListener("change", () => {
    const [field, order] = sortSelect.value.split("-");
    currentSort = field || "name";
    sortOrder = order || "asc";
    renderVehicles();
  });

  brandSelect.addEventListener("change", () => {
    currentBrand = brandSelect.value || null;
    renderVehicles();
  });

  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape" && isShopVisible()) {
      event.preventDefault();
      if (checkoutStage !== "details") {
        returnToVehicleDetails();
        return;
      }
      closeShop();
      return;
    }

    if (
      event.key === "/" &&
      isShopVisible() &&
      !["INPUT", "SELECT", "TEXTAREA"].includes(document.activeElement?.tagName)
    ) {
      event.preventDefault();
      searchInput.focus();
    }
  });

  window.addEventListener("message", (event) => {
    const data = asObject(event.data);

    switch (data.action) {
      case "open":
        handleOpen(data);
        break;

      case "handoffStarting":
        // Hide immediately without posting `close`; the in-flight purchase
        // callback remains authoritative and will finish resetting checkout state.
        setShopVisible(false);
        break;

      case "updateTestDriveTime":
        inTestDrive = true;
        showTestDriveTimer(true);
        updateTimerDisplay(data.time);
        break;

      case "testDriveEnded":
      case "resetTestDrive":
        inTestDrive = false;
        showTestDriveTimer(false);
        break;

      case "openDealerMenu":
        openDealerMenu(data.categories);
        break;

      case "updateVehicles":
        Object.assign(vehicles, asObject(data.dealerVehicles));
        activeShop.categoryOrder = normalizedCategoryOrder(activeShop.categoryOrder);
        if (currentCategory !== "all" && !categoryHasInventory(currentCategory)) {
          currentCategory = openingCategory();
        }
        setupBrandOptions();
        setupCategories();
        renderVehicles();
        break;
    }
  });

  window.addEventListener("beforeunload", () => {
    observer?.disconnect();
  });
}

// Keep these names available for compatibility with older injected markup.
window.closeVehicleInfo = closeVehicleInfo;
window.startTestDrive = startTestDrive;
window.buyVehicle = buyVehicle;
window.openDealerMenu = openDealerMenu;

bindListeners();
