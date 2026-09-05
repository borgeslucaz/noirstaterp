let currentTaxis = [];
let selectedTaxiId = null;

window.addEventListener("message", function (event) {
  const data = event.data;

  if (data.action === "openUI") {
    openTaxiPanel(data.taxis, data.stopName);
  } else if (data.action === "updateStatus") {
    updateTaxiStatus(data.taxiId, data.status, data.eta);
  } else if (data.action === "showConfirmation") {
    showConfirmationDialog(data.message);
  } else if (data.action === "close") {
    closePanel();
  } else if (data.action === "updateDemandStatus") {
    updateDemandStatus(data.taxiId, data.demandPlayerId);
  }
});

function openTaxiPanel(taxis, stopName) {
  const panel = document.getElementById("taxiPanel");
  const stopNameEl = document.getElementById("stopName");
  const driversList = document.getElementById("driversList");
  const taxiDetails = document.getElementById("taxiDetails");

  currentTaxis = taxis;
  stopNameEl.textContent = stopName;
  driversList.innerHTML = "";

  taxiDetails.innerHTML = `
    <div class="no-selection">
      <i class="fas fa-hand-pointer"></i>
      <p>Select a driver to view taxi details</p>
    </div>
  `;

  if (taxis.length === 0) {
    driversList.innerHTML = `
      <div style="text-align: center; padding: 40px; color: rgba(255,255,255,0.4);">
        <i class="fas fa-exclamation-triangle" style="font-size: 40px; margin-bottom: 10px;"></i>
        <p>No taxis available at this stop</p>
      </div>
    `;
  } else {
    taxis.forEach((taxi, index) => {
      const driverItem = createDriverItem(taxi);
      driversList.appendChild(driverItem);

      if (index === 0) {
        selectTaxi(taxi.id);
      }
    });
  }

  panel.classList.remove("hidden");
}

function createDriverItem(taxi) {
  const item = document.createElement("div");
  item.className = "driver-item";
  item.setAttribute("data-taxi-id", taxi.id);
  item.onclick = () => selectTaxi(taxi.id);

  let statusHTML = getStatusBadge(taxi.status, taxi.stopsHere);

  item.innerHTML = `
    <img src="images/${taxi.driverImage}" alt="${taxi.name}" class="driver-avatar"
         onerror="this.src='data:image/svg+xml,%3Csvg xmlns=\\'http://www.w3.org/2000/svg\\' viewBox=\\'0 0 50 50\\'%3E%3Ccircle fill=\\'%23444\\' cx=\\'25\\' cy=\\'25\\' r=\\'25\\'/%3E%3Ctext x=\\'50%25\\' y=\\'50%25\\' fill=\\'%23999\\' font-size=\\'12\\' text-anchor=\\'middle\\' dy=\\'.3em\\'%3ED%3C/text%3E%3C/svg%3E'">
    <div class="driver-item-info">
      <div class="driver-route-label">
        <i class="fas fa-id-card"></i>
        Driver ID: ${taxi.id}
      </div>
      <div class="driver-name">${taxi.name}</div>
    </div>
    <div class="status-badge">${statusHTML}</div>
  `;

  return item;
}

function getStatusBadge(status, stopsHere) {
  if (!stopsHere) {
    return '<span class="status-not-here">NOT STOP HERE</span>';
  }
  
  switch (status) {
    case "available":
      return '<span class="status-available">AVAILABLE</span>';
    case "en_route":
      return '<span class="status-en-route">EN ROUTE</span>';
    case "delivering":
      return '<span class="status-delivering">DELIVERING</span>';
    case "just_finished":
      return '<span class="status-finished">JUST FINISHED</span>';
    case "returning":
      return '<span class="status-returning">RETURNING</span>';
    default:
      return '<span class="status-available">AVAILABLE</span>';
  }
}

function updateDemandStatus(taxiId, demandPlayerId) {
    const taxi = currentTaxis.find((t) => t.id === taxiId);
    if (taxi) {
        taxi.demandedByMe = (demandPlayerId !== null && demandPlayerId !== undefined);
        
        if (selectedTaxiId === taxiId) {
            showTaxiDetails(taxi);
        }
        
        const driverItem = document.querySelector(`.driver-item[data-taxi-id="${taxiId}"]`);
        if (driverItem) {
            const statusBadge = driverItem.querySelector(".status-badge");
            if (statusBadge) {
                statusBadge.innerHTML = getStatusBadge(taxi.status, taxi.stopsHere);
            }
        }
    }
}

function selectTaxi(taxiId) {
  selectedTaxiId = taxiId;
  const taxi = currentTaxis.find((t) => t.id === taxiId);

  if (!taxi) return;

  document.querySelectorAll(".driver-item").forEach((item) => {
    item.classList.remove("active");
    if (parseInt(item.getAttribute("data-taxi-id")) === taxiId) {
      item.classList.add("active");
    }
  });

  showTaxiDetails(taxi);
}

function showTaxiDetails(taxi) {
  const taxiDetails = document.getElementById("taxiDetails");

  if (!taxi) {
    taxiDetails.innerHTML = `
      <div class="no-selection">
        <i class="fas fa-hand-pointer"></i>
        <p>Select a driver to view taxi details</p>
      </div>
    `;
    return;
  }

  let buttonText = "CALL TAXI";
  let buttonDisabled = false;
  let buttonStyle = "";
  let notifyType = "normal";

  if (taxi.demandedByMe) {
    buttonText = "TAXI RESERVED";
    buttonDisabled = true;
    buttonStyle = "opacity: 0.7; cursor: not-allowed; background: linear-gradient(135deg, #4CAF50 0%, #45a049 100%);";
  }
  else if (!taxi.stopsHere) {
    buttonText = "NOT AVAILABLE HERE";
    buttonDisabled = true;
    buttonStyle = "opacity: 0.5; cursor: not-allowed; background: rgba(255, 0, 0, 0.3);";
  }
  else if (taxi.status === "returning") {
    buttonText = "DEMAND TAXI";
    notifyType = "demand";
    buttonStyle = "background: linear-gradient(135deg, #2196f3 0%, #1976d2 100%);";
  }
  else if (taxi.status === "delivering") {
    buttonText = "DELIVERING PASSENGER";
    buttonDisabled = true;
    buttonStyle = "opacity: 0.5; cursor: not-allowed;";
  } else if (taxi.status === "en_route") {
    buttonText = "TAXI EN ROUTE";
    buttonDisabled = true;
    buttonStyle = "opacity: 0.5; cursor: not-allowed;";
  } else if (taxi.status === "just_finished") {
    buttonText = "NOTIFY WAITING";
    notifyType = "waiting";
  }

  const rgbColor = `rgb(${taxi.color.r}, ${taxi.color.g}, ${taxi.color.b})`;
  const vehicleImage = taxi.vehicleImage || taxi.image || 'taxi.png';

  const template = `
    <div class="taxi-detail-card" style="--taxi-color: ${rgbColor}">
      <div class="taxi-image-container">
        <img src="images/${vehicleImage}" alt="Taxi ${taxi.id}" class="taxi-detail-image"
             onerror="this.src='data:image/svg+xml,%3Csvg xmlns=\\'http://www.w3.org/2000/svg\\' viewBox=\\'0 0 800 300\\'%3E%3Crect fill=\\'%23333\\' width=\\'800\\' height=\\'300\\'/%3E%3Ctext x=\\'50%25\\' y=\\'50%25\\' fill=\\'%23666\\' font-size=\\'24\\' text-anchor=\\'middle\\' dy=\\'.3em\\'%3ETaxi Image%3C/text%3E%3C/svg%3E'">
      </div>

      <div class="driver-header">
        <div class="driver-title">${taxi.name}</div>
        <div class="taxi-number">TAXI ${taxi.id}</div>
      </div>

      <div class="info-grid">
        <div class="info-item">
          <div class="info-label">
            <i class="fas fa-id-card"></i>
            DRIVER NAME
          </div>
          <div class="info-value">${taxi.name}</div>
        </div>

        <div class="info-item">
          <div class="info-label">
            <i class="fas fa-taxi"></i>
            TAXI NUMBER
          </div>
          <div class="info-value">Taxi ${taxi.id}</div>
        </div>

        <div class="info-item">
          <div class="info-label">
            <i class="fas fa-signal"></i>
            STATUS
          </div>
          <div class="info-value">${getStatusText(taxi.status, taxi.stopsHere)}</div>
        </div>

        <div class="info-item">
          <div class="info-label">
            <i class="fas fa-map-marker-alt"></i>
            AVAILABILITY
          </div>
          <div class="info-value" style="color: ${taxi.status === "available" || taxi.status === "just_finished" ? "#FFFF00" : "#ff9800"};">
            <i class="fas fa-${taxi.status === "available" || taxi.status === "just_finished" ? "check-circle" : "clock"}"></i> 
            ${taxi.status === "available" || taxi.status === "just_finished" ? "Ready" : "Busy"}
          </div>
        </div>
      </div>

      <button class="call-button" data-taxi-id="${taxi.id}" data-notify-type="${notifyType}" ${buttonDisabled ? "disabled" : ""} style="${buttonStyle}">
        <i class="fas fa-${notifyType === 'demand' ? 'hand-paper' : taxi.status === "just_finished" ? "bell" : taxi.demandedByMe ? "check-circle" : "taxi"}"></i>
        ${buttonText}
      </button>
    </div>
  `;

  if (taxiDetails.innerHTML !== template) {
    taxiDetails.innerHTML = template;
    
    const callButton = taxiDetails.querySelector('.call-button');
    if (callButton && !buttonDisabled) {
      callButton.addEventListener('click', function() {
        const taxiId = parseInt(this.getAttribute('data-taxi-id'));
        const notifyType = this.getAttribute('data-notify-type');
        callTaxi(taxiId, notifyType);
      });
    }
  }
}

function getStatusText(status, stopsHere) {
  if (!stopsHere) {
    return '<span style="color: #ff5252; font-weight: 700;">Not Stop Here</span>';
  }
  
  switch (status) {
    case "available":
      return '<span style="color:rgb(208, 255, 0); font-weight: 700;">Available</span>';
    case "en_route":
      return '<span style="color:rgb(43, 226, 98); font-weight: 700;">En Route</span>';
    case "delivering":
      return '<span style="color: #ff9800; font-weight: 700;">Delivering</span>';
    case "just_finished":
      return '<span style="color: #4caf50; font-weight: 700;">Just Finished</span>';
    case "returning":
      return '<span style="color: #2196f3; font-weight: 700;">Returning</span>';
    default:
      return "Unknown";
  }
}

function updateTaxiStatus(taxiId, status, eta) {
  const taxi = currentTaxis.find((t) => t.id === taxiId);
  if (taxi) {
    taxi.status = status;
    taxi.eta = eta;

    const driverItem = document.querySelector(
      `.driver-item[data-taxi-id="${taxiId}"]`
    );
    if (driverItem) {
      const statusBadge = driverItem.querySelector(".status-badge");
      if (statusBadge) {
        statusBadge.innerHTML = getStatusBadge(status);
      }
    }

    if (selectedTaxiId === taxiId) {
      showTaxiDetails(taxi);
    }
  }
}

function callTaxi(taxiId, notifyType) {
  const taxi = currentTaxis.find((t) => t.id === taxiId);

  if (!taxi) return;

  const button = document.querySelector(`.call-button[data-taxi-id="${taxiId}"]`);
  if (!button) return;
  
  const originalText = button.innerHTML;

  if (notifyType === "waiting") {
    button.innerHTML = '<i class="fas fa-bell"></i> NOTIFYING...';
  } else {
    button.innerHTML = '<i class="fas fa-check"></i> CALLING...';
  }
  button.style.background =
    "linear-gradient(135deg, #4CAF50 0%, #45a049 100%)";

  setTimeout(() => {
    closePanel();
  }, 1000);

  $.post(
    "https://rd-taxi/notifyTaxi",
    JSON.stringify({
      taxiId: taxiId,
      notifyType: notifyType,
    })
  );
}

function showConfirmationDialog(message) {
  const dialog = document.getElementById("confirmDialog");
  const messageEl = document.getElementById("confirmMessage");

  messageEl.textContent = message;
  dialog.classList.remove("hidden");
}

function confirmWaypoint(confirmed) {
  const dialog = document.getElementById("confirmDialog");
  dialog.classList.add("hidden");

  $.post(
    "https://rd-taxi/confirmWaypoint",
    JSON.stringify({
      confirmed: confirmed,
    })
  );
}

function closePanel() {
  const panel = document.getElementById("taxiPanel");
  panel.classList.add("hidden");
  selectedTaxiId = null;
  currentTaxis = [];

  $.post("https://rd-taxi/close", JSON.stringify({}));
}

document.addEventListener("keydown", function (event) {
  if (event.key === "Escape") {
    const panel = document.getElementById("taxiPanel");
    const dialog = document.getElementById("confirmDialog");

    if (!dialog.classList.contains("hidden")) {
      confirmWaypoint(false);
    } else if (!panel.classList.contains("hidden")) {
      closePanel();
    }
  }
});

let audioUpdateInterval = null;

window.addEventListener("message", function (event) {
  const data = event.data;

  if (data.action === "openUI") {
    openTaxiPanel(data.taxis, data.stopName);
  } else if (data.action === "updateStatus") {
    updateTaxiStatus(data.taxiId, data.status, data.eta);
  } else if (data.action === "showConfirmation") {
    showConfirmationDialog(data.message);
  } else if (data.action === "close") {
    closePanel();
  } else if (data.action === "play3DAudio") {
    play3DAudio(data.audioFile, data.coords, data.vehicleNetId);
  } else if (data.action === "stop3DAudio") {
    stop3DAudio();
  }
});

function play3DAudio(audioFile, coords, vehicleNetId) {
  const audio = document.getElementById("driverVoice");
  
  audio.src = `sounds/${audioFile}`;
  audio.volume = 1.0;
  
  audio.play().catch(err => {
  });
  
  audioUpdateInterval = setInterval(() => {
    $.post("https://rd-taxi/getPlayerAndVehicleCoords", JSON.stringify({
      vehicleNetId: vehicleNetId
    }), function(response) {
      if (response && response.playerCoords && response.vehicleCoords) {
        const distance = Math.sqrt(
          Math.pow(response.playerCoords.x - response.vehicleCoords.x, 2) +
          Math.pow(response.playerCoords.y - response.vehicleCoords.y, 2) +
          Math.pow(response.playerCoords.z - response.vehicleCoords.z, 2)
        );
        
        const maxDistance = 30.0;
        let volume = 1.0 - (distance / maxDistance);
        volume = Math.max(0, Math.min(1, volume));
        
        audio.volume = volume;
      }
    });
  }, 100);
  
  audio.onended = () => {
    stop3DAudio();
  };
}

function stop3DAudio() {
  const audio = document.getElementById("driverVoice");
  audio.pause();
  audio.currentTime = 0;
  
  if (audioUpdateInterval) {
    clearInterval(audioUpdateInterval);
    audioUpdateInterval = null;
  }
}