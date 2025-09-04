import {onCall, HttpsError} from "firebase-functions/v2/https";
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
 * Berechnet die finalen Spendenbeträge für alle Sponsoren.
 */
export const calculateFinalAmounts = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError(
        "unauthenticated",
        "Benutzer ist nicht authentifiziert.",
    );
  }

  const userDoc = await admin.firestore().collection("Laufer").doc(uid).get();
  const userData = userDoc.data();

  if (userData?.role !== "admin") {
    throw new HttpsError(
        "permission-denied",
        "Diese Aktion erfordert Administrator-Rechte.",
    );
  }

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

    return {
      success: true,
      message: `${count} Spenden erfolgreich berechnet.`,
    };
  } catch (error) {
    logger.error("Fehler bei der Berechnung der Endbeträge:", error);
    throw new HttpsError(
        "internal",
        "Ein interner Fehler ist aufgetreten.",
        error,
    );
  }
});

/**
 * Versendet die finalen Rechnungs-E-Mails an alle Sponsoren.
 */
export const sendBillingEmails = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError(
        "unauthenticated",
        "Benutzer ist nicht authentifiziert.",
    );
  }
  const userDoc = await admin.firestore().collection("Laufer").doc(uid).get();
  if (userDoc.data()?.role !== "admin") {
    throw new HttpsError(
        "permission-denied",
        "Aktion erfordert Admin-Rechte.",
    );
  }

  try {
    const sponsorshipsSnapshot = await admin.firestore().collection("Spenden").get();
    const runnersSnapshot = await admin.firestore().collection("Laufer").get();

    const runnersMap = new Map<string, any>();
    runnersSnapshot.forEach((doc) => runnersMap.set(doc.id, doc.data()));

    const emailsToSend = new Map<string, any[]>();

    sponsorshipsSnapshot.forEach((doc) => {
      const sponsorship = doc.data();
      const email = sponsorship.sponsorEmail;
      if (email && sponsorship.finalerBetrag != null) { // Nur Spenden mit Betrag berücksichtigen
        if (!emailsToSend.has(email)) {
          emailsToSend.set(email, []);
        }
        emailsToSend.get(email)?.push(sponsorship);
      }
    });

    let emailCount = 0;
    const mailCollection = admin.firestore().collection("mail");

    for (const [email, sponsorships] of emailsToSend.entries()) {
      let totalAmount = 0;
      let detailsHtml = "<ul>";
      const sponsorName = sponsorships[0]?.sponsorName ?? "Sponsor";

      for (const sponsorship of sponsorships) {
        const runner = runnersMap.get(sponsorship.runnerId);
        const runnerName = runner?.name ?? "einem Läufer";
        const finalAmount = sponsorship.finalerBetrag ?? 0;
        totalAmount += finalAmount;

        let zusageText = "";
        if (sponsorship.sponsoringType === "fixed") {
          zusageText = `Fixbetrag: CHF ${sponsorship.amount.toFixed(2)}`;
        } else {
          zusageText = `${runner.rundenAnzahl ?? 0} Runden à CHF ${sponsorship.amount.toFixed(2)}`;
        }

        detailsHtml += `<li>Für <b>${runnerName}</b> (${zusageText}): <b>CHF ${finalAmount.toFixed(2)}</b></li>`;
      }
      detailsHtml += "</ul>";

      const emailContent = {
        to: [email],
        message: {
          subject: "Ihr Sponsorenbeitrag für den EVP Sponsorenlauf",
          html: `
            <p>Liebe/r ${sponsorName},</p>
            <p>herzlichen Dank für Ihre grossartige Unterstützung unseres Sponsorenlaufs!</p>
            <p>Anbei finden Sie die Zusammenfassung der Leistungen der von Ihnen unterstützten Läuferinnen und Läufer und den daraus resultierenden Gesamtbetrag Ihrer Spende.</p>
            <hr>
            ${detailsHtml}
            <hr>
            <h3>Total Sponsorenbeitrag: CHF ${totalAmount.toFixed(2)}</h3>
            <p>Wir bitten Sie, diesen Gesamtbetrag auf das folgende Konto zu überweisen:</p>
            <p>
              <b>Kontoinhaber:</b> [Ihr Kontoinhaber]<br>
              <b>IBAN:</b> [Ihre IBAN]<br>
              <b>Bank:</b> [Ihre Bank]<br>
              <b>Zahlungszweck:</b> Sponsorenlauf ${sponsorName}
            </p>
            <p>Nochmals herzlichen Dank für Ihr wertvolles Engagement!</p>
            <p>Mit freundlichen Grüssen,<br>Ihr Sponsorenlauf-Team der EVP</p>
          `,
        },
      };

      await mailCollection.add(emailContent);
      emailCount++;
    }

    return {
      success: true,
      message: `${emailCount} Rechnungs-E-Mails wurden erfolgreich versendet.`,
    };
  } catch (error) {
    logger.error("Fehler beim Versenden der Rechnungs-E-Mails:", error);
    throw new HttpsError("internal", "Ein Fehler ist aufgetreten.", error);
  }
});