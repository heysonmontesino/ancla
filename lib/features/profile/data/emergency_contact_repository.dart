import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'models/emergency_contact.dart';

class EmergencyContactRepository {
  EmergencyContactRepository._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static const int _maxContacts = 2;
  static const Stream<List<EmergencyContact>> _emptyContactsStream =
      Stream<List<EmergencyContact>>.empty();

  static String get _currentUid => _auth.currentUser?.uid ?? '';

  static CollectionReference<Map<String, dynamic>>? get _collection {
    final uid = _currentUid;
    if (uid.isEmpty) {
      return null;
    }
    return _db.collection('users').doc(uid).collection('emergency_contacts');
  }

  /// Stream en tiempo real de los contactos de emergencia (máximo 2).
  static Stream<List<EmergencyContact>> watchContacts() {
    final collection = _collection;
    if (collection == null) {
      if (kDebugMode) {
        debugPrint(
          '[EmergencyContactRepo] Sin sesión activa: se devuelve stream vacío.',
        );
      }
      return _emptyContactsStream;
    }

    try {
      return collection
          .orderBy('created_at')
          .limit(_maxContacts)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map(
                  (doc) => EmergencyContact.fromFirestore(
                    doc as DocumentSnapshot<Map<String, dynamic>>,
                  ),
                )
                .toList(),
          );
    } catch (e) {
      if (kDebugMode) debugPrint('[EmergencyContactRepo] Error al observar contactos: $e');
      return _emptyContactsStream;
    }
  }

  /// Agrega un nuevo contacto. Falla silenciosamente si ya hay 2.
  static Future<void> addContact(String name, String phone) async {
    final collection = _collection;
    if (collection == null) {
      if (kDebugMode) {
        debugPrint(
          '[EmergencyContactRepo] Sin sesión activa: no se agrega contacto.',
        );
      }
      return;
    }

    try {
      final snapshot = await collection.limit(_maxContacts).get();
      if (snapshot.docs.length >= _maxContacts) {
        if (kDebugMode) {
          debugPrint(
            '[EmergencyContactRepo] Límite de $_maxContacts contactos alcanzado.',
          );
        }
        return;
      }

      await collection.add({
        'name': name.trim(),
        'phone': phone.trim(),
        'created_at': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) debugPrint('[EmergencyContactRepo] Contacto agregado: $name');
    } catch (e) {
      if (kDebugMode) debugPrint('[EmergencyContactRepo] Error al agregar contacto: $e');
      rethrow;
    }
  }

  /// Elimina un contacto por su ID de documento.
  static Future<void> deleteContact(String contactId) async {
    final collection = _collection;
    if (collection == null) {
      if (kDebugMode) {
        debugPrint(
          '[EmergencyContactRepo] Sin sesión activa: no se elimina contacto.',
        );
      }
      return;
    }

    try {
      await collection.doc(contactId).delete();
      if (kDebugMode) debugPrint('[EmergencyContactRepo] Contacto eliminado: $contactId');
    } catch (e) {
      if (kDebugMode) debugPrint('[EmergencyContactRepo] Error al eliminar contacto: $e');
      rethrow;
    }
  }
}
