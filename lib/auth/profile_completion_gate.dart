import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:sponsorenlauf_app/pages/runner_dashboard_page.dart';
import 'package:sponsorenlauf_app/pages/public_landing_page.dart';
import 'package:sponsorenlauf_app/pages/edit_profile_page.dart';

/// Leitet Nutzer abhängig von Profil-Vollständigkeit weiter:
/// - nicht eingeloggt → PublicLandingPage
/// - Adresse unvollständig → EditProfilePage
/// - sonst → RunnerDashboardPage
class ProfileCompletionGate extends StatelessWidget {
  const ProfileCompletionGate({super.key});

  Future<_GateDecision> _decide() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return _GateDecision.toLanding;

    try {
      final doc = await FirebaseFirestore.instance.collection('Laufer').doc(user.uid).get();
      final m = (doc.data() ?? <String, dynamic>{});

      String _s(List<String> keys) {
        for (final k in keys) {
          final v = m[k];
          if (v is String && v.trim().isNotEmpty) return v.trim();
        }
        return '';
      }

      Map<String, dynamic> addr = {};
      if (m['address'] is Map<String, dynamic>) {
        addr = m['address'] as Map<String, dynamic>;
      }

      String _addr(String k) => (addr[k] ?? m[k] ?? '').toString().trim();

      final hasStreet = _addr('street').isNotEmpty;
      final hasZip    = _addr('zip').toString().trim().isNotEmpty;
      final hasCity   = _addr('city').isNotEmpty;

      final first = _s(['firstName', 'vorname']);
      final last  = _s(['lastName', 'nachname', 'name']);

      final okName = first.isNotEmpty && last.isNotEmpty;
      final okAddr = hasStreet && hasZip && hasCity;

      return (okName && okAddr)
          ? _GateDecision.toDashboard
          : _GateDecision.toEditProfile;
    } catch (_) {
      return _GateDecision.toEditProfile;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_GateDecision>(
      future: _decide(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        switch (snap.data!) {
          case _GateDecision.toLanding:
            return const PublicLandingPage();
          case _GateDecision.toEditProfile:
            return const EditProfilePage();
          case _GateDecision.toDashboard:
            return const RunnerDashboardPage();
        }
      },
    );
  }
}

enum _GateDecision { toLanding, toEditProfile, toDashboard }
