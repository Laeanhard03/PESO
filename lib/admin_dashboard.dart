import 'package:flutter/material.dart';

import 'landing_page.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;

  // --- MOCK DATABASE STATES ---
  final List<Map<String, dynamic>> _ingestedJobs = [
    {
      'id': 'BATCH-001',
      'title': 'IT Support Specialist',
      'company': 'Montalban LGU',
      'uploaded_at': 'Today, 08:30 AM',
      'status': 'Active',
    },
    {
      'id': 'BATCH-001',
      'title': 'Data Encoder',
      'company': 'Prime BPO',
      'uploaded_at': 'Today, 08:30 AM',
      'status': 'Active',
    },
  ];

  final List<Map<String, dynamic>> _preVettedPassers = [
    {
      'applicant': 'Juan Dela Cruz',
      'target_job': 'IT Support Specialist',
      'ai_score': 85,
      'status': 'Ready for Export',
    },
    {
      'applicant': 'Maria Santos',
      'target_job': 'Data Encoder',
      'ai_score': 92,
      'status': 'Ready for Export',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final Color pesoGreen = const Color(0xFF2E7D32);
    final Color sidebarColor = const Color(
      0xFF142015,
    ); // Deep forest near-black

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Row(
        children: [
          // --- DESIGNER SIDEBAR ---
          Container(
            width: 280,
            color: sidebarColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(30.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Icon(
                          Icons.admin_panel_settings,
                          color: Colors.blueAccent,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'System Admin',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'IT & Data Operations',
                        style: TextStyle(
                          color: Colors.blueAccent.shade100,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 30),
                  child: Divider(color: Colors.white12, thickness: 1),
                ),
                const SizedBox(height: 15),
                _buildSidebarItem(
                  Icons.cloud_upload_outlined,
                  'Job Batch Ingestion',
                  0,
                  Colors.blueAccent,
                ),
                _buildSidebarItem(
                  Icons.download_outlined,
                  'DOLE SPRS Export',
                  1,
                  Colors.blueAccent,
                ),
                _buildSidebarItem(
                  Icons.analytics_outlined,
                  'Platform Analytics',
                  2,
                  Colors.blueAccent,
                ),
                const Spacer(),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 30),
                  child: Divider(color: Colors.white12, thickness: 1),
                ),
                _buildSidebarItem(
                  Icons.logout,
                  'Secure Logout',
                  99,
                  Colors.redAccent,
                  isLogout: true,
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),

          // --- MAIN CONTENT AREA ---
          Expanded(
            child: Column(
              children: [
                // Minimalist Top Header
                Container(
                  height: 90,
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _getHeaderTitle(),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getHeaderSubtitle(),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.settings_outlined,
                              color: Colors.black54,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 20),
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: Colors.blueAccent.withValues(
                              alpha: 0.1,
                            ),
                            child: const Icon(
                              Icons.person,
                              color: Colors.blueAccent,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Dynamic View
                Expanded(child: _buildCurrentView(pesoGreen)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getHeaderTitle() {
    switch (_selectedIndex) {
      case 0:
        return 'PESO Offline Job Ingestion';
      case 1:
        return 'Pre-Vetted Candidates Pipeline';
      case 2:
        return 'AI Engine & System Health';
      default:
        return 'Dashboard';
    }
  }

  String _getHeaderSubtitle() {
    switch (_selectedIndex) {
      case 0:
        return 'Batch upload Excel files from PESO Admins to populate the core database.';
      case 1:
        return 'Extract passers and export data strictly into DOLE SPRS-compliant formats.';
      case 2:
        return 'Monitor live API traffic, exam generation, and system uptime.';
      default:
        return '';
    }
  }

  Widget _buildCurrentView(Color pesoGreen) {
    switch (_selectedIndex) {
      case 0:
        return _buildJobIngestionView();
      case 1:
        return _buildDataExportView(pesoGreen);
      case 2:
        return _buildAnalyticsView();
      default:
        return const Center(child: Text('View not found'));
    }
  }

  // ==========================================
  // 1. AUTO JOB EXTRACTOR (Ingestion)
  // ==========================================
  Widget _buildJobIngestionView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The Drop Zone UI
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 40),
            decoration: BoxDecoration(
              color: Colors.blue.shade50.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.blue.shade200,
                width: 2,
              ), // Acts as drop-zone border
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withValues(alpha: 0.1),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.file_upload_outlined,
                    size: 48,
                    color: Colors.blue.shade600,
                  ),
                ),
                const SizedBox(height: 25),
                const Text(
                  'Select or drop PESO Excel file here',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Only .xlsx files following the Montalban offline job template are supported.',
                  style: TextStyle(color: Colors.blue.shade700, fontSize: 14),
                ),
                const SizedBox(height: 30),
                ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Parsing Excel File... 45 Jobs synced.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  icon: const Icon(Icons.folder_open, size: 18),
                  label: const Text('Browse Files'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 35,
                      vertical: 18,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 50),

          const Text(
            'Recent Ingestion Logs',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 20),
          ..._ingestedJobs.map((job) => _buildIngestedJobCard(job)),
        ],
      ),
    );
  }

  Widget _buildIngestedJobCard(Map<String, dynamic> job) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(25),
      decoration: _designerCardDecoration(),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.work_outline, color: Colors.black54),
              ),
              const SizedBox(width: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    job['title'],
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Text(
                        job['company'],
                        style: const TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 15),
                      Text('•', style: TextStyle(color: Colors.grey.shade400)),
                      const SizedBox(width: 15),
                      Text(
                        'Batch: ${job['id']} | Uploaded: ${job['uploaded_at']}',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.circle, color: Colors.green, size: 10),
                const SizedBox(width: 8),
                Text(
                  job['status'],
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 2. DOLE SPRS DATA EXPORT (Extraction)
  // ==========================================
  Widget _buildDataExportView(Color pesoGreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sticky Action Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.filter_list, color: Colors.grey),
                  const SizedBox(width: 10),
                  Text(
                    'Showing ${_preVettedPassers.length} Pre-Vetted Candidates',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('DOLE SPRS Excel generated locally.'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.table_view, size: 18),
                    label: const Text('Generate DOLE SPRS Excel'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black87,
                      side: BorderSide(color: Colors.grey.shade300),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 15,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Data exported and emailed to PESO Admins.',
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                    icon: const Icon(Icons.send, size: 18),
                    label: const Text('Handoff to PESO Admin'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: pesoGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 25,
                        vertical: 15,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(40),
            itemCount: _preVettedPassers.length,
            itemBuilder: (context, index) {
              final passer = _preVettedPassers[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 15),
                padding: const EdgeInsets.all(25),
                decoration: _designerCardDecoration(),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: pesoGreen.withValues(alpha: 0.1),
                          child: Icon(Icons.person, color: pesoGreen),
                        ),
                        const SizedBox(width: 20),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              passer['applicant'],
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                const Text(
                                  'Target Job:',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  passer['target_job'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              'AI Assessment Score',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${passer['ai_score']}%',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: pesoGreen,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 25),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ==========================================
  // 3. PLATFORM & AI ENGINE ANALYTICS
  // ==========================================
  Widget _buildAnalyticsView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'AI Exams Generated',
                  '1,420',
                  Icons.psychology,
                  Colors.blueAccent,
                ),
              ),
              const SizedBox(width: 25),
              Expanded(
                child: _buildMetricCard(
                  'Pre-Vetted Passers',
                  '842',
                  Icons.verified,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 25),
              Expanded(
                child: _buildMetricCard(
                  'Action Plans Created',
                  '578',
                  Icons.alt_route,
                  Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(50),
            decoration: _designerCardDecoration(),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.api, size: 60, color: Colors.blue.shade600),
                ),
                const SizedBox(height: 25),
                const Text(
                  'LLM API Connection Status',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 16),
                      SizedBox(width: 8),
                      Text(
                        '100% Uptime - Healthy',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- DESIGNER UI UTILS ---

  BoxDecoration _designerCardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.02),
          blurRadius: 20,
          offset: const Offset(0, 5),
        ),
      ],
      border: Border.all(color: Colors.grey.shade100),
    );
  }

  Widget _buildMetricCard(
    String title,
    String count,
    IconData icon,
    Color accentColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: _designerCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accentColor, size: 24),
              ),
              Icon(Icons.trending_up, color: Colors.grey.shade300),
            ],
          ),
          const SizedBox(height: 25),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            count,
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(
    IconData icon,
    String title,
    int index,
    Color activeColor, {
    bool isLogout = false,
  }) {
    bool isActive = _selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 4),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: isActive
            ? activeColor.withValues(alpha: 0.15)
            : Colors.transparent,
        leading: Icon(
          icon,
          color: isActive || isLogout ? activeColor : Colors.white54,
          size: 22,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isActive || isLogout ? activeColor : Colors.white54,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            fontSize: 14,
          ),
        ),
        onTap: () {
          if (isLogout) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LandingPage()),
            );
          } else {
            setState(() => _selectedIndex = index);
          }
        },
      ),
    );
  }
}
