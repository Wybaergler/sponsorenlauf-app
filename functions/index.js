const { onDocumentCreated, onDocumentDeleted } = require("firebase-functions/v2/firestore");
const { logger } = require("firebase-functions");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");

initializeApp();

const db = getFirestore();

// Diese eine Funktion wird ausgelöst, wenn eine Spende ODER eine Runde
// erstellt ODER gelöscht wird.
exports.updateRunnerAggregatesOnTrigger = onDocumentCreated("Spenden/{spendeId}", async (event) => {
    const data = event.data.data();
    if (data.runnerId) {
        logger.info(`Sponsorship created for runner: ${data.runnerId}, updating aggregates.`);
        return updateRunnerAggregates(data.runnerId);
    }
    return null;
});

exports.updateRunnerAggregatesOnLapCreate = onDocumentCreated("Runden/{rundeId}", async (event) => {
    const data = event.data.data();
    if (data.runnerId) {
        logger.info(`Lap created for runner: ${data.runnerId}, updating aggregates.`);
        return updateRunnerAggregates(data.runnerId);
    }
    return null;
});

exports.updateRunnerAggregatesOnLapDelete = onDocumentDeleted("Runden/{rundeId}", async (event) => {
    const data = event.data.data();
    if (data.runnerId) {
        logger.info(`Lap deleted for runner: ${data.runnerId}, updating aggregates.`);
        return updateRunnerAggregates(data.runnerId);
    }
    return null;
});


// Die zentrale Berechnungsfunktion (bleibt logisch gleich)
async function updateRunnerAggregates(runnerId) {
  // 1. Alle Spenden für den Läufer holen
  const sponsorshipsSnapshot = await db
    .collection("Spenden")
    .where("runnerId", "==", runnerId)
    .get();

  let totalFixedAmount = 0;
  let totalPerLapAmount = 0;
  sponsorshipsSnapshot.forEach((doc) => {
    const data = doc.data();
    if (data.sponsoringType === "fixed") {
      totalFixedAmount += data.amount || 0;
    } else {
      totalPerLapAmount += data.amount || 0;
    }
  });

  // 2. Alle Runden für den Läufer holen und zählen
  const lapsSnapshot = await db
    .collection("Runden")
    .where("runnerId", "==", runnerId)
    .get();

  const lapCount = lapsSnapshot.size;

  // 3. Die finale Spendensumme berechnen
  const totalDonationAmount = totalFixedAmount + (totalPerLapAmount * lapCount);

  // 4. Die neuen Werte in das "Laufer"-Dokument schreiben
  const runnerRef = db.collection("Laufer").doc(runnerId);

  logger.info(`Updating runner ${runnerId}: laps=${lapCount}, donation=${totalDonationAmount}`);

  return runnerRef.set({
    rundenAnzahl: lapCount,
    aktuelleSpendensumme: totalDonationAmount,
  }, { merge: true });
}