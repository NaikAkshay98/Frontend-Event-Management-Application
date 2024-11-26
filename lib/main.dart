import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseFirestore.instance.settings = const Settings(
    host: 'localhost:8080',
    sslEnabled: false,
  );
  runApp(MyApp());
}

// State management for event filter and favorites
class EventProvider with ChangeNotifier {
  String? selectedType;
  List<String> favoriteEvents = [];

  void setSelectedType(String? type) {
    selectedType = type;
    notifyListeners();
  }

  void toggleFavorite(String eventId) {
    if (favoriteEvents.contains(eventId)) {
      favoriteEvents.remove(eventId);
    } else {
      favoriteEvents.add(eventId);
    }
    notifyListeners();
  }

  bool isFavorite(String eventId) => favoriteEvents.contains(eventId);
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => EventProvider(),
      child: MaterialApp(
        title: 'Event Manager',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          brightness: Brightness.light,
          cardTheme: const CardTheme(
            elevation: 4,
            margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          ),
        ),
        darkTheme: ThemeData(brightness: Brightness.dark),
        home: EventListScreen(),
      ),
    );
  }
}

// Event List Screen
class EventListScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<EventProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Events'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: "Search Events",
            onPressed: () {
              showSearch(context: context, delegate: EventSearch());
            },
          ),
          DropdownButton<String>(
            value: provider.selectedType,
            hint: const Text("Filter by Type", style: TextStyle(color: Colors.black)),
            items: <String>["Conference", "Workshop", "Webinar"]
                .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                .toList(),
            onChanged: (value) {
              provider.setSelectedType(value);
            },
            underline: Container(),
            dropdownColor: Colors.white,
          ),
        ],
      ),
      body: StreamBuilder(
        stream: provider.selectedType == null
            ? FirebaseFirestore.instance.collection('events').snapshots()
            : FirebaseFirestore.instance
                .collection('events')
                .where('eventType', isEqualTo: provider.selectedType)
                .snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text("Error loading events"));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No events available"));
          }
          final events = snapshot.data!.docs;
          return ListView.builder(
            itemCount: events.length,
            itemBuilder: (context, index) {
              final event = events[index];
              final isFavorite = provider.isFavorite(event.id);
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.event, color: Colors.blue),
                  title: Text(event['title']),
                  subtitle: Text(event['description']),
                  trailing: IconButton(
                    icon: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: isFavorite ? Colors.red : Colors.grey,
                    ),
                    onPressed: () {
                      provider.toggleFavorite(event.id);
                    },
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EventDetailScreen(event.id),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CreateEditEventScreen(),
            ),
          );
        },
        child: const Icon(Icons.add),
        tooltip: "Add Event",
      ),
    );
  }
}

// Search Functionality
class EventSearch extends SearchDelegate {
  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final searchQuery = query.toLowerCase();
    return StreamBuilder(
      stream: FirebaseFirestore.instance
          .collection('events')
          .where('title', isGreaterThanOrEqualTo: searchQuery)
          .snapshots(),
      builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No results found"));
        }
        final results = snapshot.data!.docs;
        return ListView.builder(
          itemCount: results.length,
          itemBuilder: (context, index) {
            final event = results[index];
            return ListTile(
              title: Text(event['title']),
              subtitle: Text(event['description']),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EventDetailScreen(event.id),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return Container();
  }
}

// Event Detail Screen
class EventDetailScreen extends StatelessWidget {
  final String eventId;

  EventDetailScreen(this.eventId);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Event Details')),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('events').doc(eventId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text("Error loading event details"));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Event not found"));
          }
          final event = snapshot.data!.data() as Map<String, dynamic>;
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event['title'],
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 10),
                Text("Description: ${event['description']}"),
                const SizedBox(height: 10),
                Text("Date: ${event['date']}"),
                const SizedBox(height: 10),
                Text("Location: ${event['location']}"),
                const SizedBox(height: 10),
                Text("Organizer: ${event['organizer']}"),
                const SizedBox(height: 10),
                Text("Type: ${event['eventType']}"),
                const SizedBox(height: 20),
                Row(
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.edit),
                      label: const Text("Edit"),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                CreateEditEventScreen(eventId: eventId),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.delete),
                      label: const Text("Delete"),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () async {
                        bool? confirmDelete = await showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text("Delete Event"),
                            content: const Text("Are you sure you want to delete this event?"),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text("Cancel"),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                child: const Text("Delete"),
                              ),
                            ],
                          ),
                        );
                        if (confirmDelete == true) {
                          try {
                            await FirebaseFirestore.instance
                                .collection('events')
                                .doc(eventId)
                                .delete();
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Event deleted successfully")),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Error deleting event: $e")),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// Create/Edit Event Screen
class CreateEditEventScreen extends StatefulWidget {
  final String? eventId;

  CreateEditEventScreen({this.eventId});

  @override
  _CreateEditEventScreenState createState() => _CreateEditEventScreenState();
}

class _CreateEditEventScreenState extends State<CreateEditEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _organizerController = TextEditingController();
  String? _eventType;
  DateTime? _date;

  @override
  void initState() {
    super.initState();
    if (widget.eventId != null) {
      FirebaseFirestore.instance.collection('events').doc(widget.eventId).get().then((doc) {
        final data = doc.data()!;
        _titleController.text = data['title'];
        _descriptionController.text = data['description'];
        _locationController.text = data['location'];
        _organizerController.text = data['organizer'];
        _eventType = data['eventType'];
        _date = DateTime.parse(data['date']);
        setState(() {});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.eventId == null ? "Create Event" : "Edit Event"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: "Title"),
                validator: (value) =>
                    value == null || value.isEmpty ? "Title is required" : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: "Description"),
                validator: (value) =>
                    value == null || value.isEmpty ? "Description is required" : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(labelText: "Location"),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _organizerController,
                decoration: const InputDecoration(labelText: "Organizer"),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _eventType,
                decoration: const InputDecoration(labelText: "Event Type"),
                items: ["Conference", "Workshop", "Webinar"]
                    .map((type) =>
                        DropdownMenuItem(value: type, child: Text(type)))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _eventType = value;
                  });
                },
                validator: (value) =>
                    value == null || value.isEmpty ? "Event type is required" : null,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _date == null
                          ? "Select Date"
                          : "Date: ${_date!.toLocal()}".split(' ')[0],
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: _date ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() {
                          _date = picked;
                        });
                      }
                    },
                    child: const Text("Pick Date"),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    try {
                      final event = {
                        "title": _titleController.text,
                        "description": _descriptionController.text,
                        "location": _locationController.text,
                        "organizer": _organizerController.text,
                        "eventType": _eventType,
                        "date": _date?.toIso8601String(),
                      };
                      if (widget.eventId == null) {
                        await FirebaseFirestore.instance.collection('events').add(event);
                      } else {
                        await FirebaseFirestore.instance.collection('events').doc(widget.eventId).update(event);
                      }
                      Navigator.pop(context);
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Error saving event: $e")),
                      );
                    }
                  }
                },
                child: const Text("Save Event"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
