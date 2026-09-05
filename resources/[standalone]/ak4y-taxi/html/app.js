var alldata = {}
var config = {}
var taximeteretc = false
var selectedvehicle = undefined
var selectedroute = undefined
var injob = false
var airon = false
var notifyTimeout
var mylevel = false
var focusKeyCode = null
var Lang = {}
var jobData = {}
var billmenu = false
var finishJobShowTimeout = null
var finishJobHideTimeout = null
var ActiveJobDetails = {
    vacant: false,
    hired: false,
    time: false,
}

function clearFinishJobTimeouts() {
    if (finishJobShowTimeout) {
        clearTimeout(finishJobShowTimeout)
        finishJobShowTimeout = null
    }
    if (finishJobHideTimeout) {
        clearTimeout(finishJobHideTimeout)
        finishJobHideTimeout = null
    }
}

function SetLeaderboard() {
    $.post("https://ak4y-taxi/GetLeaderBoard", JSON.stringify({}), function (response) {
        if (response && response.length > 0) {
            // İlk 3 için elemanlar
            const top1 = response[0]
            const top2 = response[1]
            const top3 = response[2]
            if (top1) {
                $(".LeaderBoard1 .LeaderName").text(top1.name)
                $(".LeaderBoard1 .LeaderNick").text(top1.id)
                $(".LeaderBoard1 .LeaderBoardPP1").css("background-image", `url(${top1.photo})`)
                $(".LeaderBoard1 .leveltext").text(top1.level)
            }
            if (top2) {
                $(".LeaderBoard2 .LeaderName").text(top2.name)
                $(".LeaderBoard2 .LeaderNick").text(top2.id)
                $(".LeaderBoard2 .LeaderBoardPP3").css("background-image", `url(${top2.photo})`)
                $(".LeaderBoard2 .leveltext").text(top2.level)
            }
            if (top3) {
                $(".LeaderBoard3 .LeaderName").text(top3.name)
                $(".LeaderBoard3 .LeaderNick").text(top3.id)
                $(".LeaderBoard3 .LeaderBoardPP3").css("background-image", `url(${top3.photo})`)
                $(".LeaderBoard3 .leveltext").text(top3.level)
            }

            $(".TopPlayersBox").empty()
            var TopItems = ""

            for (var i = 3; i < response.length; i++) {
                var element = response[i]
                var level = element.level
                var xp = element.xp
                var maxXp = config.Levels[level - 1].max
                var percentage = element.percentage // 0-100 arası

                var dashoffset = getStrokeDashoffset(percentage)

                TopItems += `
                    <div class="TopPlayerItem">
                        <div class="TopPlayerItemLeftCont">
                            <div class="TopPlayerItemLeftContTop">#${i} <span>${element.name}</span> </div>
                            <div class="TopPlayerItemLeftContBottom">
                                <div class="TopPlayerItemJobCountIcon"></div>
                                <div class="TopPlayerItemJobCountText">${Object.entries(element.completedroutes).length}${Lang.ui.leaderboard_routes_suffix}</div>
                                <div class="TopPlayerItemJobCountIcon" style="margin-left: 0.2vw;"></div>
                                <div class="TopPlayerItemJobCountText">${xp} Xp ${Lang.ui.accumulated}</div>
                            </div>
                        </div>
                        <div class="TopPlayerItemRightCont">
                            <div class="TopPlayerItemRightContTop">Level ${level}</div>
                            <div class="TopPlayerItemRightContBottom">${xp}/ <span>${maxXp} XP</span> </div>
                        </div>
                        <div class="TopPlayerItemRightLevel">
                            <svg class="progress-ring" width="32" height="32" viewBox="0 0 32 32" fill="none">
                                <circle
                                    class="progress-ring-bg"
                                    cx="16"
                                    cy="16"
                                    r="14"
                                    stroke="white"
                                    stroke-opacity="0.05"
                                    stroke-width="3"
                                    fill="none"
                                />
                                <circle
                                    class="progress-ring-value"
                                    cx="16"
                                    cy="16"
                                    r="14"
                                    stroke="#C87E08"
                                    stroke-width="3"
                                    fill="none"
                                    stroke-linecap="round"
                                    stroke-dasharray="87.9646"
                                    stroke-dashoffset="${dashoffset}"
                                    transform="rotate(-90 16 16)"
                                />
                            </svg>
                            <div class="leveltext">${level}</div>
                        </div>
                    </div>
                `
            }

            $(".TopPlayersBox").html(TopItems)
        }
    })
}

function getStrokeDashoffset(percent) {
    const circumference = 2 * Math.PI * 14 // 87.9646
    return circumference - (percent / 100) * circumference
}

function showSection(id) {
    if (id == "Profile") {
        ProfileMenu()
    } else if (id == "LeaderBoard") {
        SetLeaderboard()
    }

    const buttons = ["DCCMain", "LeaderBoard", "Profile"]

    buttons.forEach((section) => {
        if (section !== id) {
            $("." + section + "-button")
                .removeClass("SelectedButton")
                .addClass("UnselectedButton")
        }
    })

    const sections = ["DCCMain", "LeaderBoard", "Profile"]
    sections.forEach((section) => {
        if (section !== id) {
            $("#" + section)
                .stop(true, true)
                .fadeOut(250)
        }
    })

    $("." + id)
        .stop(true, true)
        .fadeOut(250, function () {
            const selectedButton = $("#" + id + "-button")
            selectedButton.removeClass("UnselectedButton SelectedButton").addClass("SelectedButton")

            setTimeout(function () {
                $("." + id)
                    .css("display", "flex")
                    .hide()
                    .fadeIn(300)
            }, 250)
        })
}

$(".TopButtons").first().removeClass("SelectedButton").addClass("UnselectedButton")

window.addEventListener("message", function (event) {
    let data = event.data
    switch (data.action) {
        case "init":
            config = data.data
            Lang = data.locales
            jobData = data.data.WorkZones || {}

            renderWorkZoneJobList()

            for (const key in Lang.ui) {
                const elements = document.querySelectorAll(`[data-locale="${key}"]`)
                elements.forEach((el) => {
                    el.innerHTML = Lang.ui[key]
                })
            }

            document.querySelectorAll("[data-locale-title]").forEach((el) => {
                const k = el.getAttribute("data-locale-title")
                if (k && Lang.ui[k]) el.setAttribute("title", Lang.ui[k])
            })

            document.getElementById("mousekey").innerHTML = config["Keys"]["mouse"].key
            document.getElementById("taximeteropen").innerHTML = config["Keys"]["taximeter"].key
            document.getElementById("airopenkey").innerHTML = config["Keys"]["air"].key

            $(".MainSelectVehiclesBox").empty()
            var Vehicles = ""
            for (var i = 0; i < Object.entries(config.Vehicles).length; i++) {
                var element = config.Vehicles[i]
                Vehicles += `
				<div class="VehicleItem" style="opacity: 0.5;" data-level="${element.level}" data-token="${i}">
					<div class="VehicleItemTaxiImage" style="background-image: url(${element.photo})"></div>
					<div class="VehicleItemTopContText">
						<div class="VehicleItemTopHeader">${element.label}</div>
						<div class="VehicleItemTopDesc">${Lang.ui.level_prefix}${element.level}${Lang.ui.vehicle_level_suffix}</div>
					</div>
					<div class="VehicleItemTopContButton VehicleUnSelected">${Lang.ui.vehicle_select_btn}</div>
				</div>
            `
            }
            $(".MainSelectVehiclesBox").html(Vehicles)

            break
        case "DistancePrice":
            document.getElementById("changeprice").childNodes[0].nodeValue = formatNumberFixed(
                data.price,
            )
            document.getElementById("changedistance").childNodes[0].nodeValue = formatNumberFixed(
                data.distance,
            )
            break
        case "SetFocusKey":
            focusKeyCode = data.key
            break
        case "Notify":
            showNotification(data.text, data.type)
            break
        case "SetTaximeterDetails":
            updateActiveJobDetailsFromClient(data.data)
            break
        case "ShowInvoice":
            $("body").fadeIn(500)
            $(".TaxiMeter").hide()
            $(".BillMenu").css("display", "flex").hide().fadeIn(300)
            document.getElementById("billdate").innerHTML = data.data.date
            document.getElementById("token").innerHTML = data.data.tokennmbr
            document.getElementById("customername").innerHTML = data.data.customername
            document.getElementById("myname2").innerHTML = data.data.myname
            document.getElementById("fare").innerHTML = data.data.fare + "/km"
            document.getElementById("billamount").innerHTML = data.price + "$"
            document.getElementById("billamount2").innerHTML = data.price + "$"
            document.getElementById("distancetrav").innerHTML =
                formatNumberFixed(data.distance) + " km"
            billmenu = true
            break
        case "SatisfiedCustomer":
            $(".ClientSatisfaction").css("display", "flex").hide().fadeIn(300)
            document.getElementById("ClientSatisfactionTopContBox").innerHTML = "😃"
            document.getElementById("clientstext").innerHTML = Lang.ui.satisfied_customer_title
            document.getElementById("clientsdesc").innerHTML = Lang.ui.satisfied_customer_desc
            document.querySelector(".ClientSatisfactionBottomLine").style.background =
                "rgb(64, 255, 128)"
            document.querySelector(".ClientSatisfactionBottomLine").style.boxShadow =
                "0vw -0.052vw 2.604vw 0.781vw rgba(64, 255, 128, 0.5)"
            setTimeout(() => {
                $(".ClientSatisfaction").fadeOut(300)
            }, 7000)
            break
        case "DissatisfiedCustomer":
            $(".ClientSatisfaction").css("display", "flex").hide().fadeIn(300)
            document.getElementById("ClientSatisfactionTopContBox").innerHTML = "😠"
            document.getElementById("clientstext").innerHTML = Lang.ui.dissatisfied_customer_title
            document.getElementById("clientsdesc").innerHTML = Lang.ui.dissatisfied_customer_desc
            document.querySelector(".ClientSatisfactionBottomLine").style.background =
                "rgb(255, 64, 64)"
            document.querySelector(".ClientSatisfactionBottomLine").style.boxShadow =
                "0vw -0.052vw 2.604vw 0.781vw rgba(255, 64, 64, 0.5)"
            setTimeout(() => {
                $(".ClientSatisfaction").fadeOut(300)
            }, 7000)
            break
        case "NotSatisfied":
            const percent2 = ((data.degree - 16) / (30 - 16)) * 100
            document.getElementById("SliderAltCircle").style.left = percent2 + "%"
            document.getElementById("derecetext").innerHTML =
                Math.round(data.degree * 10) / 10 + "°C"
            const airDiv = document.querySelector(".AirContitioningBottom")
            if (airDiv) {
                airDiv.style.background = "rgba(255, 0, 30, 0.25)"
                airDiv.style.color = "#FF001E"
                airDiv.innerText = Lang.ui.customer_dissatisfied_air
            }

            document.querySelectorAll(".AirContitioningBottomx").forEach((el) => {
                el.style.backgroundImage = "url('./img/icons/xvector.png')"
            })
            break
        case "Satisfied":
            const percent = ((data.degree - 16) / (30 - 16)) * 100
            document.getElementById("SliderAltCircle").style.left = percent + "%"
            document.getElementById("derecetext").innerHTML =
                Math.round(data.degree * 10) / 10 + "°C"
            const airDiv2 = document.querySelector(".AirContitioningBottom")
            if (airDiv2) {
                airDiv2.style.background = "rgba(0, 255, 55, 0.25)"
                airDiv2.style.color = "#FFFFFF"
                airDiv2.innerText = Lang.ui.customer_satisfied_air
            }
            document.querySelectorAll(".AirContitioningBottomx").forEach((el) => {
                el.style.backgroundImage = "url('./img/icons/xvectorwhite.png')"
            })
            break
        case "OpenMenu":
            clearFinishJobTimeouts()
            $(".JobDoneMenu").hide()
            OpenMenu(data.data)
            break
        case "FinishJob":
            clearFinishJobTimeouts()
            injob = false
            selectedvehicle = false
            selectedroute = false
            closemenuall()
            finishJobShowTimeout = setTimeout(() => {
                $("body").fadeIn(500)
                $(".MainMenu").hide()
                $(".JobDoneMenu").css("display", "flex").hide().fadeIn(300)

                document.getElementById("clients").innerHTML =
                    data.totalclient + " " + Lang.ui.clients_suffix
                document.getElementById("time").innerHTML = data.totaltime
                document.getElementById("moneyearns").innerHTML =
                    data.earnedmoney + "$ " + Lang.ui.money_job_suffix
                document.getElementById("Dissatisfied").innerHTML =
                    data.dissatisfiedcustomer + " " + Lang.ui.clients_suffix
                document.getElementById("Satisfied").innerHTML =
                    data.satisfiedcustomer + " " + Lang.ui.clients_suffix
                finishJobHideTimeout = setTimeout(() => {
                    $("body").fadeOut(500)
                    $(".JobDoneMenu").fadeOut(500)
                }, 3500)
            }, 1000)
            break
        case "AirScreen":
            clearFinishJobTimeouts()
            $("body").fadeIn(500)
            if (injob) {
                $(".MainMenu").hide()
            }
            if (data.bool) {
                $(".AirContitioning").css("display", "flex").hide().fadeIn(300)
            } else {
                $(".AirContitioning").hide()
            }
            break
        case "TaxiMeter":
            clearFinishJobTimeouts()
            $("body").show(0)
            if (injob) {
                $(".MainMenu").hide()
            }
            if (data.bool) {
                $(".TaxiMeter").css("display", "flex").hide().fadeIn(0)
            } else {
                $(".TaxiMeter").hide()
            }
            break
        case "InVehicle":
            injob = true
            $("body").fadeIn(500)
            $(".MainMenu").hide()
            $(".KeybindButtonsCont").css("display", "flex").hide().fadeIn(300)
            break
        case "OutVehicle":
            $(".KeybindButtonsCont").fadeOut(500)
            break
        case "AgainInvehicle":
            injob = true
            $(".KeybindButtonsCont").css("display", "flex").hide().fadeIn(300)
            break
    }
})

function formatNumberFixed(num) {
    // İki ondalık basamaklı yap, toplam 5 karakter olsun (örneğin "01.60")
    let str = num.toFixed(2) // "1.60"
    if (str.length < 5) {
        str = "0".repeat(5 - str.length) + str // başına 0 ekle
    }
    return str
}

$(document).on("click", ".VacantBox", function () {
    const isSelected = $(this).hasClass("TaxiMeterselected")
    const hireon = $(".HiredBox").hasClass("TaxiMeterselected")
    if (hireon) {
        $.post("https://ak4y-taxi/CancelJob", JSON.stringify({}))
    }
    if (isSelected) {
        $(this).removeClass("TaxiMeterselected").addClass("TaxiMeterUnselected")
        ActiveJobDetails.vacant = false
    } else {
        $(".VacantBox, .HiredBox").removeClass("TaxiMeterselected").addClass("TaxiMeterUnselected")

        $(this).removeClass("TaxiMeterUnselected").addClass("TaxiMeterselected")
        ActiveJobDetails.vacant = true
        ActiveJobDetails.hired = false
    }

    $.post(
        "https://ak4y-taxi/ChangeDetails",
        JSON.stringify({
            data: ActiveJobDetails,
        }),
    )
})

$(document).on("click", ".HiredBox", function () {
    const isSelected = $(this).hasClass("TaxiMeterselected")

    if (isSelected) {
        $(this).removeClass("TaxiMeterselected").addClass("TaxiMeterUnselected")
        ActiveJobDetails.hired = false
        $.post("https://ak4y-taxi/CancelJob", JSON.stringify({}))
    } else {
        $(".VacantBox, .HiredBox").removeClass("TaxiMeterselected").addClass("TaxiMeterUnselected")

        $(this).removeClass("TaxiMeterUnselected").addClass("TaxiMeterselected")
        ActiveJobDetails.hired = true
        ActiveJobDetails.vacant = false
    }

    $.post(
        "https://ak4y-taxi/ChangeDetails",
        JSON.stringify({
            data: ActiveJobDetails,
        }),
    )
})

$(document).on("click", ".TimeOff", function () {
    const isSelected = $(this).hasClass("TaxiMeterselected")

    $(this).toggleClass("TaxiMeterselected TaxiMeterUnselected")

    ActiveJobDetails.time = !isSelected

    if (ActiveJobDetails.time) {
        $(this).text(Lang.ui.time_on)
    } else {
        $(this).text(Lang.ui.time_off)
    }

    $.post(
        "https://ak4y-taxi/ChangeDetails",
        JSON.stringify({
            data: ActiveJobDetails,
        }),
    )
})

$(document).on("click", ".EndTripBill", function () {
    $.post("https://ak4y-taxi/EndTrip")
})

$(document).on("click", ".VehicleUnSelected, .VehicleSelected", function () {
    const button = $(this)
    const vehicleItem = button.closest(".VehicleItem")
    const token = vehicleItem.data("token")
    const level = vehicleItem.data("level")
    if (Number(level) <= mylevel) {
        selectedvehicle = token
        $(".VehicleItem").css("opacity", "0.5")
        $(".VehicleItemTopContButton")
            .removeClass("VehicleSelected")
            .addClass("VehicleUnSelected")
            .text(Lang.ui.vehicle_select_btn)

        button
            .removeClass("VehicleUnSelected")
            .addClass("VehicleSelected")
            .text(Lang.ui.vehicle_selected_btn)

        button.closest(".VehicleItem").css("opacity", "1")
    } else {
        showNotification(Lang.game.not_enough_level, "error")
    }
})

function renderWorkZoneJobList() {
    const container = document.querySelector(".MainSelectJobContLeftCont")
    if (!container || !jobData) return
    const keys = Object.keys(jobData)
    const selectLabel = Lang.ui && Lang.ui.vehicle_select_btn ? Lang.ui.vehicle_select_btn : "SELECT"
    let html = ""
    for (let i = 0; i < keys.length; i++) {
        const key = keys[i]
        const jd = jobData[key]
        if (!jd) continue
        const label = jd.label || key
        html += `
            <div class="MainSelectJob UnSelectedJob" data-job="${key}">
                <div class="MainSelectJobLabel">${label}</div>
                <div class="MainSelectJobButton UnSelectedJobButton" data-job="${key}">${selectLabel}</div>
            </div>
        `
    }
    container.innerHTML = html
}

function collapseSelectedJobsToUnselected() {
    document.querySelectorAll(".MainSelectJob.SelectedJob").forEach((el) => {
        let routeKey = el.getAttribute("data-route")
        if (!routeKey || !jobData[routeKey]) {
            const labelText = el.querySelector(".MainSelectectedJobLabel")?.textContent
            routeKey = Object.keys(jobData).find((k) => jobData[k].label === labelText)
            if (!routeKey && labelText) {
                const t = labelText.trim().toLowerCase()
                routeKey = Object.keys(jobData).find((k) => k.toLowerCase() === t)
            }
        }
        if (!routeKey || !jobData[routeKey]) return
        const jd = jobData[routeKey]
        const selectLabel = Lang.ui && Lang.ui.vehicle_select_btn ? Lang.ui.vehicle_select_btn : "SELECT"
        const unselectedHTML = `
            <div class="MainSelectJob UnSelectedJob" data-job="${routeKey}">
                <div class="MainSelectJobLabel">${jd.label}</div>
                <div class="MainSelectJobButton UnSelectedJobButton" data-job="${routeKey}">${selectLabel}</div>
            </div>
        `
        const temp = document.createElement("div")
        temp.innerHTML = unselectedHTML
        el.replaceWith(temp.firstElementChild)
    })
}

function OpenMenu(data) {
    mylevel = data.level
    alldata = data
    $("body").fadeIn(500)
    $(".MainMenu").css("display", "flex").hide().fadeIn(300)

    // İlk aracı seç
    if (config.Vehicles && config.Vehicles.length > 0) {
        selectedvehicle = 0 // İlk araç indexi
    } else {
        selectedvehicle = undefined
    }

    collapseSelectedJobsToUnselected()
    const zoneKeys = Object.keys(jobData || {})
    selectedroute =
        zoneKeys.indexOf("downtown") >= 0 ? "downtown" : zoneKeys.length > 0 ? zoneKeys[0] : undefined

    document.querySelectorAll(".VehicleItem").forEach((vehicleItem) => {
        vehicleItem.style.opacity = "0.5"

        const button = vehicleItem.querySelector(".VehicleItemTopContButton")
        if (button && button.classList.contains("VehicleSelected")) {
            button.classList.remove("VehicleSelected")
            button.classList.add("VehicleUnSelected")
            button.textContent = Lang.ui.vehicle_select_btn
        }
    })

    if (selectedvehicle !== undefined) {
        const vehicleItem = document.querySelector(`.VehicleItem[data-token="${selectedvehicle}"]`)
        if (vehicleItem) {
            vehicleItem.style.opacity = "1"
            const button = vehicleItem.querySelector(".VehicleItemTopContButton")
            if (button) {
                button.classList.remove("VehicleUnSelected")
                button.classList.add("VehicleSelected")
                button.textContent = Lang.ui.vehicle_selected_btn
            }
        }
    }

    document.getElementById("requiredlevel").innerHTML = "NON SELECTED"
    document.getElementById("pricecont").innerHTML = "NON SELECTED"
    document.getElementById("xpcont").innerHTML = "NON SELECTED"

    $("#ProfilePic2").css("background-image", `url(${data.photo})`)
    $("#ProfilePic").css("background-image", `url(${data.photo})`)
    $("#TopContainerRightLevel")
        .contents()
        .filter(function () {
            return this.nodeType === 3
        })
        .first()
        .replaceWith(data.level)
    $("#myleveltext").text(Lang.ui.level_prefix + data.level)
    $("#myname").text(data.name)

    if (selectedroute !== undefined) {
        const dataJob = jobData[selectedroute]
        if (dataJob) {
            const startLabel = Lang.ui && Lang.ui.startjob ? Lang.ui.startjob : "Start Job"
            const selectedHTML = `
                <div class="MainSelectJob SelectedJob" data-route="${selectedroute}" style="background-image: url('${dataJob.bg}')">
                    <div class="MainSelectedJobLeft">
                        <div class="MainSelectectedJobLabel">${dataJob.label}</div>
                        <div class="MainSelectectedJobDesc">${dataJob.desc}</div>
                    </div>
                    <div class="MainSelectedJobButton SelectedJobButton" data-job="${dataJob.label}">${startLabel}</div>
                </div>
            `
            const routeRow = Array.from(
                document.querySelectorAll(".MainSelectJob.UnSelectedJob"),
            ).find((el) => el.getAttribute("data-job") === selectedroute)
            if (routeRow) {
                const temp2 = document.createElement("div")
                temp2.innerHTML = selectedHTML
                routeRow.replaceWith(temp2.firstElementChild)
            }

            document.getElementById("requiredlevel").innerHTML =
                Lang.ui.level_prefix + dataJob.minLevel + Lang.ui.required
            document.getElementById("pricecont").innerHTML =
                Lang.ui.per_customer_price_prefix + dataJob.price.min + "-$" + dataJob.price.max
            document.getElementById("xpcont").innerHTML =
                Lang.ui.per_customer_xp_prefix +
                dataJob.xp.min +
                "-" +
                dataJob.xp.max +
                Lang.ui.per_customer_xp_suffix
        }
    } else {
        document.getElementById("requiredlevel").innerHTML = "NON SELECTED"
        document.getElementById("pricecont").innerHTML = "NON SELECTED"
        document.getElementById("xpcont").innerHTML = "NON SELECTED"
    }

    if (Object.entries(data.tasks).length > 0) {
        $(".MainDailyTasksCont").empty()
        var Tasks = ""
        for (var i = 0; i < Object.entries(data.tasks).length; i++) {
            var element = data.tasks[i]
            var percentage = 0
            if (element.Need > 0) {
                percentage = (element.Current / element.Need) * 100
                if (percentage > 100) percentage = 100
            }
            var complete = "TaskItemNonComplete"
            var completetext = Lang.ui.task_not_complete
            if (element.taken) {
                complete = "TaskItemComplete"
                completetext = Lang.ui.task_complete
            }
            Tasks += `
                <div class="TaskItem">
                    <div class="TaskItemTop">
                        <div class="TaskItemLeftHead">${element.Name}</div>
                        <div class="TaskItemXpBox">${element.xp}xp
                            <div class="LevelRightBorder"></div>
                            <div class="LevelLeftBorder"></div>
                            <div class="LevelBottomBorder"></div>
                            <div class="LevelTopBorder"></div>
                        </div>
                    </div>
                    <div class="TaskItemMid">${element.desc}</div>
                    <div class="TaskItemCompleteBox">
                        <div class="${complete}"></div>
                        <div class="TaskItemCompleteText">${completetext}</div>
                        <div class="TaskItemProgress">
                            <div class="TaskItemProgressIn" style="width: ${percentage}%;"></div>
                        </div>
                        <div class="TaskItemProgressText">${element.Current}/${element.Need}</div>
                    </div>
                </div>
            `
        }
        $(".MainDailyTasksCont").html(Tasks)
    } else {
        $(".MainDailyTasksCont").empty()
    }

    showSection("DCCMain")
}

$(document).on("keydown", function () {
    switch (event.keyCode) {
        case 27: // ESC
            closemenu()
            break
        case focusKeyCode:
            closemenu()
            break
    }
})

function closemenu() {
    if (!billmenu) {
        if (injob) {
            $.post("https://ak4y-taxi/closeMenu", JSON.stringify())
        } else {
            // $('body').fadeOut(500);
            const sections = ["DCCMain", "LeaderBoard", "Profile", "MainMenu"]
            sections.forEach((section) => {
                $("#" + section)
                    .stop(true, true)
                    .fadeOut(250)
            })
            $.post("https://ak4y-taxi/closeMenu", JSON.stringify())
        }
    } else {
        showNotification(Lang.game.pay_first, "error")
    }
}

function closemenuall() {
    $("body").fadeOut(500)
    const sections = [
        "DCCMain",
        "LeaderBoard",
        "Profile",
        "MainMenu",
        "KeybindButtonsCont",
        "ClientSatisfaction",
        "TaxiMeter",
        "BillMenu",
        "JobDoneMenu",
        "AirContitioning",
    ]
    sections.forEach((section) => {
        $("#" + section)
            .stop(true, true)
            .fadeOut(250)
    })
    $.post("https://ak4y-taxi/closeMenu", JSON.stringify())
}

var TAXIMETER_STORAGE_KEY = "ak4y-taxi-taximeter-pos"
function applyTaximeterSavedPosition() {
    try {
        var raw = localStorage.getItem(TAXIMETER_STORAGE_KEY)
        if (!raw) return
        var pos = JSON.parse(raw)
        if (typeof pos.left === "number" && typeof pos.top === "number") {
            $("#TaxiMeter").css({
                position: "fixed",
                left: pos.left + "px",
                top: pos.top + "px",
                right: "auto",
                bottom: "auto",
            })
        }
    } catch (e) {}
}

function initTaximeterDrag() {
    var $meter = $("#TaxiMeter")
    var $handle = $("#TaxiMeterDragHandle")
    var startX, startY, startLeft, startTop

    $handle.on("mousedown", function (e) {
        e.preventDefault()
        var rect = $meter[0].getBoundingClientRect()
        startX = e.clientX
        startY = e.clientY
        startLeft = rect.left
        startTop = rect.top
        $meter.css({
            position: "fixed",
            left: startLeft + "px",
            top: startTop + "px",
            right: "auto",
            bottom: "auto",
        })

        function onMove(e) {
            var left = startLeft + (e.clientX - startX)
            var top = startTop + (e.clientY - startY)
            $meter.css({ left: left + "px", top: top + "px" })
        }
        function onUp() {
            $(document).off("mousemove.taximeter mouseup.taximeter")
            var rect = $meter[0].getBoundingClientRect()
            try {
                localStorage.setItem(
                    TAXIMETER_STORAGE_KEY,
                    JSON.stringify({
                        left: Math.round(rect.left),
                        top: Math.round(rect.top),
                    }),
                )
            } catch (err) {}
        }
        $(document).on("mousemove.taximeter", onMove).on("mouseup.taximeter", onUp)
    })
}

document.addEventListener("DOMContentLoaded", function () {
    applyTaximeterSavedPosition()
    initTaximeterDrag()
    document.querySelector(".MainSelectJobContLeftCont").addEventListener("click", (e) => {
        const row = e.target.closest(".MainSelectJob.UnSelectedJob")
        if (!row) return
        const routeKey = row.getAttribute("data-job")
        if (!routeKey) return
        const data = jobData[routeKey]
        if (!data) return

        const newRoute = routeKey

        collapseSelectedJobsToUnselected()

        selectedroute = newRoute

        document.getElementById("requiredlevel").innerHTML =
            Lang.ui.level_prefix + data.minLevel + Lang.ui.required
        document.getElementById("pricecont").innerHTML =
            "$" + data.price.min + "-$" + data.price.max + Lang.ui.per + "  1 " + Lang.ui.customer
        document.getElementById("xpcont").innerHTML =
            data.xp.min + "-" + data.xp.max + " XP " + Lang.ui.per + " 1 Job"

        const startLabel = Lang.ui && Lang.ui.startjob ? Lang.ui.startjob : "Start Job"
        const selectedHTML = `
      <div class="MainSelectJob SelectedJob" data-route="${selectedroute}" style="background-image: url('${data.bg}')">
        <div class="MainSelectedJobLeft">
          <div class="MainSelectectedJobLabel">${data.label}</div>
          <div class="MainSelectectedJobDesc">${data.desc}</div>
        </div>
        <div class="MainSelectedJobButton SelectedJobButton" data-job="${data.label}">${startLabel}</div>
      </div>
    `
        const temp2 = document.createElement("div")
        temp2.innerHTML = selectedHTML
        row.replaceWith(temp2.firstElementChild)
    })

    const slider = document.querySelector(".AirSlider")
    const levelBox = document.querySelector(".AirContinerMidLevelChangerBoxLevel")
    const levelBox2 = document.getElementById("AirSliderBox")
    const thumb = document.querySelector(".AirSliderThumb") // daireyi temsil eden elementin class/id'si, kendi HTML'ne göre değiştir

    function updateLevelBoxWidth(value) {
        $.post(
            "https://ak4y-taxi/SetSliderLevel",
            JSON.stringify({
                level: value,
            }),
        )
        // value 1-5 arası, genişliği yüzde olarak hesapla
        const percent = (value / 5) * 100 - 6
        levelBox.style.width = percent + "%"
        levelBox2.style.width = percent + "%"

        // Thumb pozisyonu için de aynı yüzdeyi kullan (örnek)
        if (thumb) {
            thumb.style.left = percent + "%"
        }
    }

    // Başlangıçta genişliği ayarla
    updateLevelBoxWidth(slider.value)

    // Slider değiştiğinde genişliği ve thumb pozisyonunu güncelle
    slider.addEventListener("input", () => {
        updateLevelBoxWidth(slider.value)
    })
})

function ProfileMenu() {
    document.getElementById("earnedmoney").innerHTML = alldata.earnedmoney + "$"
    document.getElementById("earnedmoney2").innerHTML = alldata.earnedmoney + "$"

    document.getElementById("mylevel").innerHTML = "LEVEL" + alldata.level
    document.getElementById("mylevel2").innerHTML = "LEVEL" + alldata.level

    document.getElementById("completedroutes").innerHTML = Object.entries(
        alldata.completedroutes,
    ).length
    document.getElementById("completedroutes2").innerHTML = Object.entries(
        alldata.completedroutes,
    ).length
    document.getElementById("myxp").innerHTML = alldata.xp + "XP"

    const levels = config.Levels
    const xp = alldata.xp

    for (let i = 0; i < levels.length; i++) {
        const level = levels[i]
        if (xp >= level.min && xp <= level.max) {
            const levelXPRange = level.max - level.min
            const currentProgress = xp - level.min

            const percent = Math.floor((currentProgress / levelXPRange) * 100)
            const xpLeft = level.max - xp

            document.querySelector("#needxp span").innerHTML = xpLeft + " xp"

            document.getElementById("nextlevelpercentage").style.width = percent + "%"

            break
        }
    }

    $(".LastRoutesBottomContCont").empty()
    var LastRoutes = ""
    for (var i = 0; i < Object.entries(alldata.completedroutes).length; i++) {
        var element = alldata.completedroutes[i]
        LastRoutes += `
		<div class="LastRoutesItem">
			<div class="LastRouteTypeLeft">NPC</div>
			<div class="LastRouteLeftIcon"></div>
			<div class="LastRouteLeftName">${element.name}</div>
			<div class="LastRouteCabBox">Cab Area
				<div class="LogoWhiteBlur"></div>
				<div class="LevelRightBorder"></div>
				<div class="LevelLeftBorder"></div>
				<div class="LevelBottomBorder"></div>
				<div class="LevelTopBorder"></div>
			</div>
			<div class="LastRouteRightCont">
				<div class="LastRouteMoneyIcon"></div>
				<div class="LastRouteMoneyText">${Lang.ui.last_route_money}${element.money}</div>
				<div class="LastRouteXPIcon"></div>
				<div class="LastRouteXPText">${Lang.ui.last_route_xp}${element.xp}</div>
			</div>
		</div>
        `
    }
    $(".LastRoutesBottomContCont").html(LastRoutes)
}

$(document).on("click", "#exitair", function () {
    $(".AirContitioning").fadeOut(300)
})

$(document).on("click", ".TaximetereCloseX", function () {
    $(".TaxiMeter").fadeOut(300)
})

$(document).on("click", ".SelectedJobButton", function () {
    if (selectedvehicle === undefined) {
        return showNotification(Lang.ui.select_vehicle_first, "error")
    }

    if (selectedroute === undefined) {
        return showNotification(Lang.ui.select_route_first, "error")
    }

    $.post(
        "https://ak4y-taxi/startJob",
        JSON.stringify({
            vehicle: selectedvehicle,
            route: selectedroute,
        }),
    )

    closemenu()
})

$(document).on("click", ".ConfirmPaymentBox", function () {
    $.post("https://ak4y-taxi/PayBill", JSON.stringify({}), function (response) {
        if (response) {
            billmenu = false
            closemenuall()
            $(".TaxiMeter").hide()
        } else {
            showNotification(Lang.ui.payment_failed, "error")
        }
    })
})

function updateActiveJobDetailsFromClient(data) {
    $("body").show()
    $(".MainMenu").hide()
    $(".TaxiMeter").css("display", "flex").hide().fadeIn(0)
    ActiveJobDetails = data

    // Butonları güncelle
    if (ActiveJobDetails.vacant) {
        $(".VacantBox").removeClass("TaxiMeterUnselected").addClass("TaxiMeterselected")
    } else {
        $(".VacantBox").removeClass("TaxiMeterselected").addClass("TaxiMeterUnselected")
    }

    if (ActiveJobDetails.hired) {
        $(".HiredBox").removeClass("TaxiMeterUnselected").addClass("TaxiMeterselected")
    } else {
        $(".HiredBox").removeClass("TaxiMeterselected").addClass("TaxiMeterUnselected")
    }

    if (ActiveJobDetails.time) {
        $(".TimeOff")
            .removeClass("TaxiMeterUnselected")
            .addClass("TaxiMeterselected")
            .text(Lang.ui.time_on)
    } else {
        $(".TimeOff")
            .removeClass("TaxiMeterselected")
            .addClass("TaxiMeterUnselected")
            .text(Lang.ui.time_off)
    }
}

$(document).on("click", "#AirClose", function () {
    airon = false
    $("#AirClose").addClass("AirOpen").removeClass("AirClosed active")
    $("#AirOpen").addClass("AirClosed").removeClass("AirOpen active")
    $("#AirClose").addClass("active") // Tıklanan aktif olsun
    $.post("https://ak4y-taxi/SetAir", JSON.stringify({ airon: airon }))
})

$(document).on("click", "#AirOpen", function () {
    airon = true
    $("#AirOpen").addClass("AirOpen").removeClass("AirClosed active")
    $("#AirClose").addClass("AirClosed").removeClass("AirOpen active")
    $("#AirOpen").addClass("active") // Tıklanan aktif olsun
    $.post("https://ak4y-taxi/SetAir", JSON.stringify({ airon: airon }))
})

function showNotification(message, type) {
    $(".NotifyFailed, .NotifySuccess, .NotifyWrong").hide()

    const u = Lang.ui || {}
    let $target
    if (type === "success") {
        $target = $(".NotifySuccess")
        $target.find(".NotifyRightConTop").text(u.notify_success || "SUCCESS!")
    } else if (type === "error") {
        $target = $(".NotifyFailed")
        $target.find(".NotifyRightConTop").text(u.notify_failed || "FAILED!")
    } else if (type === "inform") {
        $target = $(".NotifyWrong")
        $target.find(".NotifyRightConTop").text(u.notify_notice || "NOTICE!")
    } else {
        console.warn("Invalid notify type:", type)
        return
    }

    $target.find(".NotifyRightConBottom").text(message)

    if (notifyTimeout) {
        clearTimeout(notifyTimeout)
    }

    $target.stop(true, true).css("display", "flex").hide().fadeIn(300)

    notifyTimeout = setTimeout(() => {
        $target.fadeOut(500)
    }, 5000)
}
