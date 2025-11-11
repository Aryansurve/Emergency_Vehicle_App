# 🚑 Ambulance Preemption & Real-Time Tracking System

This project is a full-stack, real-time platform designed to reduce emergency response times. It provides a simulation of a **Traffic Signal Preemption (TSP)** system, allowing an ambulance to "request" green lights from traffic signals along its optimal route.

The system is built with a **Flutter** mobile application for drivers and a **Node.js (Express)** backend for dispatch, authentication, and real-time socket communication.

---

## ✨ Features

* **Real-Time Dispatch:** A platform-wide admin can see all pending emergencies and assign them to available drivers.
* **Multi-Stage Verification:** A robust, multi-step approval process for new drivers (Hospital Admin Approval -> Platform Admin Approval).
* **Role-Based Authentication:** Four distinct user roles with different permissions (Public User, Driver, Hospital Admin, Platform Admin).
* **Traffic-Aware Routing:** Generates an optimal route using the Google Routes API, complete with a multi-colored polyline showing live traffic (Normal, Slow, Jammed).
* **Turn-by-Turn Navigation:** A custom navigation UI with live instructions, ETA, and a rotating vehicle icon.
* **Signal Preemption Simulation:** The app's core feature. It automatically:
    1.  Fetches all traffic signal locations along the route via the **Overpass API**.
    2.  Clusters signals into junctions.
    3.  Runs a simulation that moves the vehicle along the route.
    4.  Automatically turns the next two upcoming junctions **Green** and reverts passed junctions to **Red**.

---

## 🚀 Demo & Outputs


### Preemption Simulation

The video below demonstrates the core TSP simulation. The ambulance (blue arrow) moves along the route, and the system automatically "preempts" the next two upcoming junctions, changing their icons from **Red** to **Green**. Once the vehicle passes a junction, it's reverted to **Red**.


[Watch the Simulation Demo.mp4](https://drive.google.com/file/d/1lSxrh86O_y6Y4pen25oqEF8-DWwlcsIm/view?usp=drive_link)

### 🚀 Demo & Outputs

*(This is the "Outputs" section you requested, polished for your repository.)*

#### Preemption Simulation

The video below demonstrates the core TSP simulation. The ambulance (blue arrow) moves along the route, and the system automatically "preempts" the next two upcoming junctions, changing their icons from **Red** to **Green**. Once the vehicle passes a junction, it's reverted to **Red**.

[Watch the Simulation Demo.mp4](https://drive.google.com/file/d/1lSxrh86O_y6Y4pen25oqEF8-DWwlcsIm/view?usp=drive_link)

#### Key Screens

| Clustered Junctions | Turn-by-Turn UI |
| :---: | :---: |
| ![Multiple signals at an intersection clustered into one marker](https_placeholder.com/path/to/your/image_545053.png) |
<img width="276" height="576" alt="Turn-by-turn UI" src="https://github.com/user-attachments/assets/1c25008f-5e72-4c40-99d9-943e4f3a788f"> |

| Admin & Dispatch | Driver Approval | Public User Report |
| :---: | :---: | :---: |
| ![Platform Admin dashboard with unassigned emergencies](https_placeholder.com/path/to/your/admin_dash.jpg) | 
![Driver Approval Screen](https://github.com/user-attachments/assets/9a4dea30-3648-40df-9279-91abcd43934c) | 
![Public User Report Screen](https://github.com/user-attachments/assets/0d7437a6-f0e8-415e-be90-7748f57371bd) |

## 💻 Tech Stack

| Area | Technology | Purpose |
| :--- | :--- | :--- |
| **Frontend** | Flutter & Dart | Cross-platform mobile application for drivers. |
| | Google Maps SDK | Primary map, routing, and polyline rendering. |
| | Geolocator | Real-time GPS tracking and heading. |
| | `http` | Consuming the backend REST API. |
| | `socket_io_client` | Real-time communication with the dispatch server. |
| **Backend** | Node.js, Express.js | REST API server for all logic and authentication. |
| | Socket.IO | Real-time websocket server for dispatch & location. |
| | MongoDB | Primary database for users, hospitals, and emergencies. |
| | Mongoose | Object Data Modeling (ODM) for MongoDB. |
| | JSON Web Token (JWT) | Secure, role-based user authentication. |
| | Redis | Blacklisting JWTs on logout for enhanced security. |
| **External APIs** | **Google Routes API** | Generating traffic-aware routes and turn-by-turn data. |
| | **Overpass API** | Querying OpenStreetMap data for traffic signal locations. |

---

## 🛠️ Getting Started

To get a local copy up and running, follow these steps.

### Prerequisites

* Node.js & npm installed
* Flutter SDK installed
* A running MongoDB instance
* A running Redis instance (optional, for token blacklisting)

### 1. Backend Setup (`EMERGENCY_VEHICLE_BACKEND`)

1.  Navigate to the backend directory:
    ```sh
    cd EMERGENCY_VEHICLE_BACKEND
    ```
2.  Install NPM packages:
    ```sh
    npm install
    ```
3.  Create a `.env` file in the root and add your environment variables:
    ```
    PORT=5000
    MONGO_URI=your_mongodb_connection_string
    JWT_SECRET=your_jwt_secret_key
    ```
4.  Start the server:
    ```sh
    npm start
    ```
    The server will be running on `http://localhost:5000`.

### 2. Frontend Setup (`EMERGENCY_VEHICLE_APP`)

1.  Navigate to the frontend directory:
    ```sh
    cd EMERGENCY_VEHICLE_APP
    ```
2.  Install Flutter packages:
    ```sh
    flutter pub get
    ```
3.  **Update API Key:**
    * In `lib/screens/map_screen.dart`, replace `YOUR_GOOGLE_API_KEY_HERE` with your actual Google Maps API key.
4.  **Update IP Address:**
    * In `lib/services/api_service.dart`, change the `_baseUrl` to match your backend's IP address (e.g., `http://192.168.0.127:5000/api/v1`).
5.  Run the app:
    ```sh
    flutter run
    ```

---

## 🏛️ System Architecture & Roles

The platform is built around four distinct user roles, defined in `userModel.js`:

1.  **Platform Admin (`Admin`)**
    * Has full oversight.
    * Can view all pending emergencies and dispatch drivers.
    * Performs the *final* verification for new drivers.
    * Can create new Hospital Admin accounts.

2.  **Hospital Admin (`HospitalAdmin`)**
    * Manages a single, assigned hospital.
    * Performs the *first* verification for new drivers from their hospital.
    * Can approve or reject new driver applications.

3.  **Driver (`Driver`)**
    * The primary mobile app user.
    * Must be verified to log in.
    * Can toggle availability (Online/Offline).
    * Receives dispatched missions in real-time.
    * Can use the "Start Nav" (real GPS) or "Start Sim" (demo) modes.

4.  **Public User (`PublicUser`)**
    * Can register a simple account.
    * Can submit a new emergency request (location, details).
    * Can track the status of their submitted emergency.

---

## 📄 License

This project is licensed under the MIT License - see the `LICENSE.md` file for details.
