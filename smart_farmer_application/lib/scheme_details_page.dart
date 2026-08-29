import 'package:flutter/material.dart';
import 'dashboard.dart'; // For colors
import 'government_schemes_page.dart'; // For SchemeModel

class SchemeDetailsPage extends StatelessWidget {
  final SchemeModel scheme;

  const SchemeDetailsPage({
    super.key,
    required this.scheme,
  });

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 20.0),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInfoText(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: greyText,
        fontSize: 13,
        height: 1.5,
      ),
    );
  }

  Widget _buildList(List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 6.0, right: 8.0),
                child: Icon(
                  Icons.circle,
                  size: 6,
                  color: primaryGreen,
                ),
              ),
              Expanded(
                child: Text(
                  item,
                  style: const TextStyle(
                    color: greyText,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Scheme Details',
          style: TextStyle(
            color: Colors.white,
            fontSize: 21,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: primaryGreen.withValues(alpha: 0.12),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: darkGreen,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      scheme.icon,
                      color: primaryGreen,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    scheme.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    scheme.shortDescription,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: primaryGreen,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 12),

            _buildSectionHeader('What is this scheme?'),
            _buildInfoText(scheme.whatIsIt),

            _buildSectionHeader('💰 Benefit'),
            _buildList(scheme.benefits),

            _buildSectionHeader('👨‍🌾 Eligibility'),
            _buildList(scheme.eligibility),

            _buildSectionHeader('📄 Documents'),
            _buildList(scheme.documents),

            _buildSectionHeader('📝 How to Apply'),
            _buildList(scheme.howToApply),

            const SizedBox(height: 30),

            const Text(
              'Note: Scheme rules and application procedures may change according to government guidelines.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: greyText,
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
