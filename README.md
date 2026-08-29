# 🌾 Smart Farmer Application

## 📌 Overview

**Smart Farmer Application** is an intelligent Flutter-based agricultural platform designed to help farmers make better farming decisions through digital tools, real-time information, and AI-powered assistance.

The application brings multiple farming services together in a single platform, helping farmers monitor their farms, identify crop diseases, access market prices, check weather conditions, explore government schemes, and get AI-based farming guidance.

---

## 🚀 Key Features

### 🌱 Farm Management

* Farmer profile and farm information management
* Crop management
* Farm Health Score
* Crop health monitoring

### 🤖 Farm Mitra – AI Farming Assistant

* AI-powered agricultural chatbot
* Farming-related question answering
* Crop and fertilizer guidance
* Conversational history
* English-language assistance

### 🦠 Disease Detection

* Upload crop images
* AI-based crop disease identification
* Disease information and recommendations
* Disease detection history

### 🌦️ Weather Information

* Current weather conditions
* Temperature and humidity
* Wind information
* Weather alerts
* 7-day forecast

### 📈 Market Prices

* Agricultural commodity prices
* Crop-wise market information
* Market/APMC price information

### 🏛️ Government Schemes

* Government agricultural schemes
* Scheme details and eligibility information
* Farmer-oriented scheme discovery

### 🔔 Notifications

* Weather alerts
* Market price updates
* Crop alerts
* Disease alerts
* Government scheme updates

### 👨‍🌾 My Crops

* Add and manage crops
* View added crops on the dashboard
* Crop-related information

---

## 🛠️ Technology Stack

| Technology              | Purpose                                    |
| ----------------------- | ------------------------------------------ |
| Flutter                 | Mobile/Desktop/Web application development |
| Dart                    | Application programming language           |
| Firebase Authentication | User authentication                        |
| Cloud Firestore         | Database and user data                     |
| Firebase AI Logic       | AI integration                             |
| Gemini                  | AI-powered farming assistance              |
| Open-Meteo              | Weather data                               |
| Firebase Services       | Backend and cloud services                 |

---

## 🏗️ Application Architecture

```text
                    Smart Farmer Application
                              │
             ┌────────────────┼────────────────┐
             │                │                │
          Flutter           Firebase          APIs
             │                │                │
        ┌────┴────┐      ┌────┴────┐      ┌────┴────┐
        │         │      │         │      │         │
    Dashboard   Pages   Auth    Firestore  Weather  Market
        │
   ┌────┼────┬────┬────┬────┬────┐
   │    │    │    │    │    │
 Crops Weather Farm  AI   Disease Schemes
              Health Mitra Detection
```

---

## 📂 Project Structure

```text
smart-farmer-application/
│
├── android/
├── ios/
├── lib/
│   ├── dashboard.dart
│   ├── farm_health_page.dart
│   ├── farm_mitra_page.dart
│   ├── disease_detection_page.dart
│   ├── market_prices_page.dart
│   ├── government_schemes_page.dart
│   ├── detailed_weather_page.dart
│   ├── my_crops_page.dart
│   ├── notifications_page.dart
│   ├── profile_page.dart
│   └── main.dart
│
├── functions/
├── test/
├── web/
├── windows/
├── macos/
├── linux/
├── pubspec.yaml
└── README.md
```

---

## ⚙️ Installation & Setup

### 1. Clone the repository

```bash
git clone https://github.com/siddhant2006721/smart-farmer-application.git
```

### 2. Open the project

```bash
cd smart-farmer-application
```

### 3. Install Flutter dependencies

```bash
flutter pub get
```

### 4. Configure Firebase

Configure your Firebase project and add the required Firebase configuration files for the target platform.

### 5. Run the application

```bash
flutter run
```

---

## 🔐 Security

Sensitive credentials and API keys should **not** be committed to the repository.

Use secure configuration and environment-specific settings for production deployments.

---

## 🎯 Objective

The main objective of Smart Farmer Application is to provide farmers with an accessible digital platform that combines:

**AI + Weather + Crop Management + Disease Detection + Market Information + Government Schemes**

into a single intelligent farming ecosystem.

---

## 🔮 Future Scope

* IoT-based soil monitoring
* Real-time soil moisture integration
* Advanced crop yield prediction
* Multilingual AI assistant
* Voice-based farmer assistance
* Satellite-based crop monitoring
* Personalized fertilizer recommendations
* Offline-first functionality for rural areas
* Advanced agricultural analytics

---

## 👨‍💻 Developer

**Siddhant Sachin Kadam**

Computer Science & Engineering

---

## 📄 License

This project is developed for educational and project demonstration purposes.
