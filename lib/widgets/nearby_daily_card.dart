import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:spoonshare/screens/fooddetails/food_details.dart';

class NearbyDailyFoodCard extends StatelessWidget {
  const NearbyDailyFoodCard({Key? key, this.dailyActive = false})
      : super(key: key);
  final bool dailyActive;

  Future<double> _calculateDistance(
      GeoPoint foodLocation, Position userLocation) async {
    double distanceInMeters = Geolocator.distanceBetween(
      userLocation.latitude,
      userLocation.longitude,
      foodLocation.latitude,
      foodLocation.longitude,
    );
    return distanceInMeters;
  }

  String calculateTimeDifference(Timestamp timestamp) {
    final currentTime = DateTime.now();
    final uploadTime = timestamp.toDate();
    final difference = currentTime.difference(uploadTime);

    if (difference.inHours < 1) {
      return '${difference.inMinutes} mins ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hr ago';
    } else {
      return '${difference.inDays} days ago';
    }
  }

  void _navigateToFoodDetails(BuildContext context, Map<String, dynamic> data) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FoodDetailsScreen(data: data),
      ),
    );
  }

  Widget buildCard(Map<String, dynamic> data, String uploadTime,
      bool isNGOVerified, Position userLocation) {
    GeoPoint foodLocation = data['location'];
    return FutureBuilder<double>(
      future: _calculateDistance(foodLocation, userLocation),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        }

        return Card(
          margin: const EdgeInsets.all(8),
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  image: DecorationImage(
                    image: NetworkImage(data['imageUrl'] ?? ''),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          data['venue'],
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8), // Add some spacing here
                        if (isNGOVerified)
                          const Icon(Icons.verified,
                              color: Colors.green, size: 16),
                        if (!isNGOVerified)
                          const Icon(Icons.cancel, color: Colors.red, size: 16),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      data['address'],
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        fontFamily: "DM Sans",
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 0),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Text(
                      'Uploaded By: ${data['fullName']}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Food Type: ${data['foodType']}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 0),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Text(
                      'Uploaded: $uploadTime',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Daily: ${data['dailyActive']}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('food')
          .doc('sharedfood')
          .collection('foodData')
          .where('dailyActive', isEqualTo: dailyActive)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        }

        List<QueryDocumentSnapshot<Map<String, dynamic>>> foodDocs =
            snapshot.data?.docs ?? [];

        return FutureBuilder<Position>(
          future: Geolocator.getCurrentPosition(),
          builder: (context, positionSnapshot) {
            if (positionSnapshot.connectionState == ConnectionState.waiting) {
              return Container(
                alignment: Alignment.center,
                child: const CircularProgressIndicator(),
              );
            } else if (positionSnapshot.hasError) {
              return Text('Error: ${positionSnapshot.error}');
            }

            Position userLocation = positionSnapshot.data!;

            // Filter and sort food docs by location and verification status
            foodDocs.sort((a, b) {
              GeoPoint aLocation = a.data()['location'];
              GeoPoint bLocation = b.data()['location'];
              double distanceA = Geolocator.distanceBetween(
                userLocation.latitude,
                userLocation.longitude,
                aLocation.latitude,
                aLocation.longitude,
              );
              double distanceB = Geolocator.distanceBetween(
                userLocation.latitude,
                userLocation.longitude,
                bLocation.latitude,
                bLocation.longitude,
              );
              bool isVerifiedA = a.data()['verified'] ?? false;
              bool isVerifiedB = b.data()['verified'] ?? false;

              // Sort by verification status first
              if (isVerifiedA != isVerifiedB) {
                return isVerifiedB ? 1 : -1; // Verified items come first
              } else {
                // If verification status is the same, sort by distance
                return distanceA.compareTo(distanceB);
              }
            });

            // Filter out documents beyond 30 km
            foodDocs = foodDocs.where((doc) {
              GeoPoint foodLocation = doc.data()['location'];
              double distance = Geolocator.distanceBetween(
                userLocation.latitude,
                userLocation.longitude,
                foodLocation.latitude,
                foodLocation.longitude,
              );
              return distance <= 30000; // 30 km in meters
            }).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 5),
                ...(foodDocs.isEmpty
                    ? [const Text('No data available.')]
                    : [
                        ...foodDocs.map((doc) {
                          Map<String, dynamic> data = doc.data();
                          Timestamp timestamp = data['timestamp'];
                          String uploadTime =
                              calculateTimeDifference(timestamp);
                          bool isNGOVerified = data['verified'] ?? false;

                          return GestureDetector(
                            onTap: () => _navigateToFoodDetails(context, data),
                            child: buildCard(
                                data, uploadTime, isNGOVerified, userLocation),
                          );
                        }),
                      ]),
                const SizedBox(height: 5),
              ],
            );
          },
        );
      },
    );
  }
}
