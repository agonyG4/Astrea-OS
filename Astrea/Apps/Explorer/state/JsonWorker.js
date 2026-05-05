WorkerScript.onMessage = function(msg) {
    try {
        var items = JSON.parse(msg.text)
        WorkerScript.sendMessage({ ok: true, items: items })
    } catch(e) {
        WorkerScript.sendMessage({ ok: false, error: String(e) })
    }
}
