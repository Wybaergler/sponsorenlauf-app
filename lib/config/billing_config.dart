class BillingConfig {
  // Organisation / Zahlung
  static const orgName = 'EVP Wetzikon';
  static const iban = 'CH10 0900 0000 8004 3019 2'; // TODO: echte IBAN einsetzen
  static const paymentRefPrefix = 'Rechnung EVP Sponsorenlauf 2025'; // für Betreff/Zahlungszweck

  // Absender/Kommunikation
  static const fromDisplay = 'Sponsorenlauf EVP Wetzikon';
  static const contactEmail = ''; // Kontakt/Reply-To (optional)

  // Archiv/BCC
  static const bccEmail = ''; // optional

  // Testmodus
  static const testMode = true; // true => sendet NICHT an Sponsor, sondern an testRecipient
  static const testRecipient = 'adminsponsorenlauf@rothe.ch'; // <- HIER deine Mail einsetzen

  // Währung
  static const currency = 'CHF';
}
