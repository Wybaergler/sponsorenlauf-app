// Diese Datei hilft uns, Daten auf eine saubere und typsichere Weise
// an unsere Seiten zu übergeben, wenn wir mit benannten Routen navigieren.

class SponsoringPageArguments {
  final String runnerId;
  final String? sponsorshipId;

  SponsoringPageArguments({
    required this.runnerId,
    this.sponsorshipId,
  });
}