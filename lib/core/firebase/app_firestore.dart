import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

/// The Firestore database this app uses.
///
/// The Firebase project's database is named "default" (without brackets),
/// which is a different database from the SDK's built-in "(default)". Every
/// repository must use this getter instead of `FirebaseFirestore.instance`,
/// otherwise reads and writes go to a database that doesn't exist and data
/// only lives in the phone's cache until Firebase rejects it.
const String appDatabaseId = 'default';

FirebaseFirestore get appFirestore => FirebaseFirestore.instanceFor(
  app: Firebase.app(),
  databaseId: appDatabaseId,
);
