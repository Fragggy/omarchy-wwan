function parseTabValues(raw) {
  var result = {}
  var lines = String(raw || "").split(/\r?\n/)
  for (var i = 0; i < lines.length; i++) {
    var at = lines[i].indexOf("\t")
    if (at < 0) continue
    var key = lines[i].slice(0, at).trim()
    if (key) result[key] = lines[i].slice(at + 1).trim()
  }
  return result
}

function number(value, fallback) {
  var parsed = Number(value)
  return isFinite(parsed) ? parsed : fallback
}

function connected(info) {
  return String((info || {}).profile_state || "").toLowerCase() === "activated"
}

function signalIcon(signal, state, locked) {
  if (locked) return "󰿅"
  if (state === "failed" || state === "disabled") return "󰞃"
  var value = number(signal, -1)
  if (value < 0) return "󰣂"
  var icons = ["󰣂", "󰢿", "󰣀", "󰣁"]
  return icons[Math.max(0, Math.min(3, Math.ceil(value / 25)))]
}

function nextRates(previous, sample, now) {
  var prev = previous || {}
  var current = sample || {}
  var rx = number(current.rx_bytes, -1)
  var tx = number(current.tx_bytes, -1)
  var timestamp = Number(now || 0)
  var sameInterface = String(prev.iface || "") === String(current.iface || "")
  var elapsed = timestamp - Number(prev.time || 0)
  var download = 0
  var upload = 0
  if (sameInterface && elapsed > 0 && rx >= Number(prev.rx || 0) && tx >= Number(prev.tx || 0)) {
    download = (rx - Number(prev.rx || 0)) * 1000 / elapsed
    upload = (tx - Number(prev.tx || 0)) * 1000 / elapsed
  }
  return { iface: String(current.iface || ""), rx: Math.max(0, rx), tx: Math.max(0, tx), time: timestamp, download: download, upload: upload }
}

function formatRate(bytes) {
  var value = Math.max(0, number(bytes, 0))
  var units = ["B/s", "KB/s", "MB/s", "GB/s"]
  var index = 0
  while (value >= 1024 && index < units.length - 1) { value /= 1024; index++ }
  var digits = value >= 100 || index === 0 ? 0 : (value >= 10 ? 1 : 2)
  return value.toFixed(digits) + " " + units[index]
}

if (typeof module !== "undefined") module.exports = { parseTabValues, connected, signalIcon, nextRates, formatRate }
