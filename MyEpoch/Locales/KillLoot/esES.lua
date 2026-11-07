local _,E=...
if E.locale~="esES" then return end
E.Localize({
    ["Loot from this defeat"]="Botín de esta victoria",
    ["Looking for loot from this defeat…"]="Buscando el botín de esta victoria…",
    ["No loot encounter has been linked yet."]="Todavía no se ha vinculado ningún hallazgo de botín.",
    ["Matched to the defeated creature."]="Vinculado a la criatura derrotada.",
    ["Approximate match · nearby kill and loot."]="Vínculo aproximado · victoria y botín cercanos.",
    ["Exact and approximate matches"]="Vínculos exactos y aproximados",
    ["Loot observed"]="Botín observado",
    ["Quantity not recorded"]="Cantidad no registrada",
    ["Related defeat"]="Victoria relacionada",
    ["Loot encounters"]="Hallazgos de botín",
    ["Loot encounter details"]="Detalles del botín hallado",
    ["Dismiss approximate match"]="Descartar el vínculo aproximado",
    ["Restore dismissed loot matches"]="Restaurar los vínculos de botín descartados",
    ["One encounter, all its items. Reopening the same corpse does not add another drop."]="Un hallazgo con todos sus objetos. Volver a abrir el mismo cadáver no cuenta como otro botín.",
    ["Observed drops do not identify who received them."]="El botín observado no indica quién lo recibió.",
    ["Open loot encounter"]="Abrir el botín hallado",
    ["Recorded receipts"]="Recepciones registradas",
    ["Loot window · {date}"]="Ventana de botín · {date}",
    ["Item {id}"]="Objeto {id}",
    ["Matching loot is still being prepared. Reopen this entry to refresh it."]="El botín correspondiente aún se está preparando. Vuelve a abrir esta entrada para actualizarla.",
})
