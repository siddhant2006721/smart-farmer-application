import 'package:flutter/material.dart';
import 'dashboard.dart'; // For colors
import 'scheme_details_page.dart';

class SchemeModel {
  final String name;
  final String shortDescription;
  final IconData icon;
  final String whatIsIt;
  final List<String> benefits;
  final List<String> eligibility;
  final List<String> documents;
  final List<String> howToApply;

  SchemeModel({
    required this.name,
    required this.shortDescription,
    required this.icon,
    required this.whatIsIt,
    required this.benefits,
    required this.eligibility,
    required this.documents,
    required this.howToApply,
  });
}

class GovernmentSchemesPage extends StatelessWidget {
  const GovernmentSchemesPage({super.key});

  static final List<SchemeModel> schemes = [
    SchemeModel(
      name: 'PM-KISAN',
      shortDescription: 'Income support of ₹6,000 per year for farmer families.',
      icon: Icons.payments_outlined,
      whatIsIt: 'Pradhan Mantri Kisan Samman Nidhi (PM-KISAN) is a central sector scheme that provides income support to all landholding farmer families in the country to supplement their financial needs for procuring various inputs related to agriculture.',
      benefits: [
        'Financial benefit of ₹6,000 per year.',
        'Amount is transferred directly to the bank account in 3 equal installments of ₹2,000 every 4 months.',
      ],
      eligibility: [
        'All landholding farmer families.',
        'Must have cultivable land holding in their name.',
      ],
      documents: [
        'Aadhaar Card',
        'Bank Account Details',
        'Land Ownership Records',
      ],
      howToApply: [
        'Step 1: Visit the official PM-KISAN portal (pmkisan.gov.in) or your nearest Common Service Centre (CSC).',
        'Step 2: On the portal, go to \'Farmers Corner\' and click on \'New Farmer Registration\'.',
        'Step 3: Enter your Aadhaar number, select your state, and complete the Captcha to authenticate.',
        'Step 4: Fill in your personal details, bank account information, and land holding records.',
        'Step 5: Submit the application and note down the registration/reference number.',
        'Step 6: You can track your application status under \'Status of Self Registered Farmer/CSC Farmer\'.',
      ],
    ),
    SchemeModel(
      name: 'Pradhan Mantri Fasal Bima Yojana (PMFBY)',
      shortDescription: 'Crop insurance scheme to protect against non-preventable natural risks.',
      icon: Icons.shield_outlined,
      whatIsIt: 'PMFBY aims to provide insurance coverage and financial support to the farmers in the event of failure of any of the notified crop as a result of natural calamities, pests & diseases.',
      benefits: [
        'Comprehensive insurance cover against crop failure.',
        'Helps stabilize the income of farmers to ensure their continuance in farming.',
        'Encourages farmers to adopt innovative and modern agricultural practices.',
      ],
      eligibility: [
        'All farmers growing notified crops in a notified area.',
        'Includes sharecroppers and tenant farmers.',
      ],
      documents: [
        'Aadhaar Card',
        'Bank Account Details',
        'Land Records / Tenancy Agreement',
        'Sowing Certificate',
      ],
      howToApply: [
        'Step 1: Contact your bank branch, nearest Common Service Centre (CSC), or authorized insurance agent/broker.',
        'Step 2: For online application, visit the National Crop Insurance Portal (pmfby.gov.in).',
        'Step 3: Register as a farmer on the portal using your Aadhaar and mobile number.',
        'Step 4: Select the relevant season (Kharif/Rabi), year, and your state/district.',
        'Step 5: Provide details of your land, crop sown, and bank account for premium deduction/claim settlement.',
        'Step 6: Pay the nominal premium amount to complete your crop insurance enrollment.',
      ],
    ),
    SchemeModel(
      name: 'Kisan Credit Card (KCC)',
      shortDescription: 'Credit scheme to provide adequate and timely credit support.',
      icon: Icons.credit_card_outlined,
      whatIsIt: 'The Kisan Credit Card scheme aims to provide adequate and timely credit support from the banking system under a single window with flexible and simplified procedure to the farmers.',
      benefits: [
        'Flexible limit and simplified procedures for credit.',
        'Covers post-harvest expenses and consumption requirements of farmer households.',
        'Investment credit requirement for agriculture and allied activities.',
      ],
      eligibility: [
        'All Farmers - Individuals / Joint borrowers who are owner cultivators.',
        'Tenant Farmers, Oral Lessees & Share Croppers.',
        'Self Help Groups (SHGs) or Joint Liability Groups (JLGs) of farmers.',
      ],
      documents: [
        'Aadhaar Card or PAN Card (ID Proof)',
        'Address Proof',
        'Land holding documents',
        'Recent passport size photographs',
      ],
      howToApply: [
        'Step 1: Download the KCC application form from the official website of the Ministry of Agriculture (agricoop.nic.in) or visit your nearest bank branch.',
        'Step 2: Fill out the application form with your personal and agricultural land details.',
        'Step 3: Attach the required KYC documents (Aadhaar, PAN), passport size photographs, and land holding records.',
        'Step 4: Submit the form at a commercial bank, regional rural bank, or cooperative bank branch.',
        'Step 5: The bank will verify your documents, land records, and determine your loan eligibility.',
        'Step 6: Once approved, the bank will issue your Kisan Credit Card and a passbook.',
      ],
    ),
    SchemeModel(
      name: 'Pradhan Mantri Krishi Sinchayee Yojana (PMKSY)',
      shortDescription: 'Scheme to improve farm water use efficiency (More crop per drop).',
      icon: Icons.water_drop_outlined,
      whatIsIt: 'PMKSY has been formulated with the vision of extending the coverage of irrigation and improving water use efficiency in a focused manner with end to end solution on source creation, distribution, management, field application and extension activities.',
      benefits: [
        'Subsidy on micro-irrigation systems (drip and sprinkler).',
        'Water conservation and increased crop yield.',
        'Reduced cost of labor and fertilizer.',
      ],
      eligibility: [
        'All farmers (small, marginal, and large) who have land in their own name.',
        'Farmers grouped in cooperative societies or self-help groups.',
      ],
      documents: [
        'Aadhaar Card',
        'Bank Account Details',
        'Land Ownership Records',
        'Passport Size Photograph',
      ],
      howToApply: [
        'Step 1: Visit the District Agriculture/Horticulture Office or contact the village Agriculture Extension Officer.',
        'Step 2: Obtain the PMKSY application form for the \'Per Drop More Crop\' micro-irrigation component.',
        'Step 3: Fill out the form and attach documents like Aadhaar, land records, and a quotation from an authorized vendor/manufacturer.',
        'Step 4: Submit the application to the respective agriculture/horticulture department for verification.',
        'Step 5: After field inspection and departmental approval, the installation of the drip/sprinkler system is carried out.',
        'Step 6: The subsidy amount is released directly to the registered vendor or farmer\'s bank account after physical verification.',
      ],
    ),
    SchemeModel(
      name: 'PM-KUSUM',
      shortDescription: 'Subsidy for setting up standalone solar pumps and solarizing existing grid-connected pumps.',
      icon: Icons.solar_power_outlined,
      whatIsIt: 'Pradhan Mantri Kisan Urja Suraksha evam Utthaan Mahabhiyan (PM-KUSUM) aims to provide energy security along with financial and water security to farmers through solar energy.',
      benefits: [
        'Significant subsidy for setting up solar water pumps.',
        'Reduces dependency on diesel and grid electricity.',
        'Option to sell surplus solar power to the grid.',
      ],
      eligibility: [
        'Individual farmers, group of farmers, cooperatives, panchayats, or Farmer Producer Organizations (FPOs).',
        'Must have land and an irrigation requirement.',
      ],
      documents: [
        'Aadhaar Card',
        'Bank Account Details',
        'Land Documents (Khasra/Khatauni)',
        'Passport Size Photograph',
      ],
      howToApply: [
        'Step 1: Identify the component you are applying for (e.g., Component B for standalone solar pumps).',
        'Step 2: Visit the official website of your State Nodal Agency (SNA) for renewable energy or agriculture department.',
        'Step 3: Register on the SNA portal by providing Aadhaar, land details (Khasra/Khatauni), and bank information.',
        'Step 4: Fill the application form for a solar pump and submit the non-refundable application fee (if applicable).',
        'Step 5: Once shortlisted/approved, deposit your farmer\'s share of the cost to the designated SNA account.',
        'Step 6: The empaneled vendor will install the solar pump in your field and commission the system.',
      ],
    ),
    SchemeModel(
      name: 'Soil Health Card',
      shortDescription: 'Provides information on soil nutrient status and recommendations for fertilizers.',
      icon: Icons.science_outlined,
      whatIsIt: 'The Soil Health Card Scheme promotes soil test based nutrient management. It provides information to farmers on the nutrient status of their soil along with recommendations on appropriate dosage of nutrients to be applied for improving soil health and its fertility.',
      benefits: [
        'Tells farmers the exact health and nutrient status of their soil.',
        'Helps in applying the correct amount of fertilizers, reducing input cost.',
        'Increases crop yield by addressing specific nutrient deficiencies.',
      ],
      eligibility: [
        'All farmers are eligible.',
        'No specific land holding criteria, applies to any agricultural land.',
      ],
      documents: [
        'Aadhaar Card',
        'Land Details',
        'No complex documentation, mostly requires field details during sample collection.',
      ],
      howToApply: [
        'Step 1: Generally, soil samples are collected by staff of the State Agriculture Department or local panchayat from farmers\' fields.',
        'Step 2: Alternatively, you can visit the local agriculture department office, Krishi Vigyan Kendra (KVK), or a nearby soil testing laboratory.',
        'Step 3: Register your farm details (Aadhaar, mobile number, land survey number) on the Soil Health Card portal (soilhealth.dac.gov.in) or offline.',
        'Step 4: Collect a representative soil sample from your field as per the standard procedure and submit it to the lab.',
        'Step 5: Pay the nominal soil testing fee, if any.',
        'Step 6: Once the testing is complete, you will receive a printed Soil Health Card with specific fertilizer and nutrient recommendations.',
      ],
    ),
  ];

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
          'Government Schemes',
          style: TextStyle(
            color: Colors.white,
            fontSize: 21,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
        itemCount: schemes.length + 1, // +1 for the note at the end
        itemBuilder: (context, index) {
          if (index == schemes.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'Note: Scheme rules and application procedures may change according to government guidelines.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: greyText,
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            );
          }

          final scheme = schemes[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: primaryGreen.withValues(alpha: 0.10),
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SchemeDetailsPage(scheme: scheme),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: darkGreen,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          scheme.icon,
                          color: primaryGreen,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              scheme.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              scheme.shortDescription,
                              style: const TextStyle(
                                color: greyText,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                const Text(
                                  'View Details',
                                  style: TextStyle(
                                    color: primaryGreen,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  color: primaryGreen,
                                  size: 10,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
