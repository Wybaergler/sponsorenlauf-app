import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {setGlobalOptions} from "firebase-functions/v2";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";

admin.initializeApp();

setGlobalOptions({region: "europe-west6"});

/**
 * Holt die aggregierte Rundenanzahl für alle Läufer.
 * @return {Promise<Map<string, number>>} Eine Map von laeuferId -> anzahlRunden.
 */
async function getLapCounts(): Promise<Map<string, number>> {
  const lapCounts = new Map<string, number>();
  const runnersSnapshot = await admin.firestore().collection("Laufer").get();

  runnersSnapshot.forEach((doc) => {
    const data = doc.data();
    const runnerId = doc.id;
    const lapCount = data.rundenAnzahl ?? 0;
    lapCounts.set(runnerId, lapCount);
  });

  return lapCounts;
}

/**
 * Löst die finale Berechnung der Spendenbeträge aus.
 * Wird getriggert, wenn ein neues Dokument in der 'abrechnungen'-Sammlung
 * erstellt wird.
 */
export const triggerFinalAmountCalculation = onDocumentCreated(
    "abrechnungen/{docId}",
    async (event) => {
      const snapshot = event.data;
      if (!snapshot) {
        logger.log("Keine Daten beim Trigger-Event, Abbruch.");
        return;
      }
      const data = snapshot.data();
      const adminUid = data.triggeredBy;

      logger.log(`Abrechnung gestartet durch Admin: ${adminUid}`);

      try {
        const lapCounts = await getLapCounts();
        const sponsorshipsRef = admin.firestore().collection("Spenden");
        const sponsorshipsSnapshot = await sponsorshipsRef.get();

        const batch = admin.firestore().batch();
        let count = 0;

        sponsorshipsSnapshot.forEach((doc) => {
          const sponsorship = doc.data();
          if (sponsorship.runnerId) {
            const runnerId = sponsorship.runnerId;
            const lapCount = lapCounts.get(runnerId) ?? 0;
            let finalAmount = 0;

            if (sponsorship.sponsoringType === "fixed") {
              finalAmount = sponsorship.amount;
            } else if (sponsorship.sponsoringType === "perLap") {
              finalAmount = sponsorship.amount * lapCount;
            }

            batch.update(doc.ref, {finalerBetrag: finalAmount});
            count++;
          }
        });

        await batch.commit();

        logger.log(`${count} Spenden erfolgreich berechnet.`);
        await snapshot.ref.update({
          status: "erfolgreich",
          anzahlSpenden: count,
        });
      } catch (error) {
        logger.error("Fehler bei der Berechnung der Endbeträge:", error);
        await snapshot.ref.update({
          status: "fehler",
          fehlerMeldung: String(error),
        });
      }
    },
);