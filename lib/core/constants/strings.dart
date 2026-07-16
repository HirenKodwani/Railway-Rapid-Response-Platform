// App-wide string constants for the Indian Railways RRS

class AppStrings {
  AppStrings._(); // Prevent instantiation

  // --- App Identity ---
  static const String appName = 'Indian Railways';
  static const String appSubtitle = 'Rapid Response System';
  static const String appFullName = 'Indian Railways Rapid Response System';

  // --- API Configuration ---
  /// Base URL for the backend API
  /// For Android emulator: 10.0.2.2:5000
  /// For iOS simulator: localhost:5000
  /// For physical device: use your machine's local IP
  static const String apiBaseUrl = 'https://r2p-aj2e.onrender.com/api';
  
  // --- Auth Strings ---
  static const String loginTitle = 'Welcome Back';
  static const String loginSubtitle = 'Sign in to continue';
  static const String emailOrPhone = 'Email or Phone';
  static const String password = 'Password';
  static const String confirmPassword = 'Confirm Password';
  static const String login = 'Login';
  static const String loggingIn = 'Signing in...';
  static const String logout = 'Logout';
  static const String logoutConfirm = 'Are you sure you want to logout?';

  // --- User Management Strings ---
  static const String users = 'Users';
  static const String createUser = 'Create User';
  static const String creatingUser = 'Creating user...';
  static const String userCreated = 'User created successfully!';
  static const String noUsers = 'No users found';
  static const String noUsersHint = 'Tap the + button to create a new user';

  // --- Form Field Labels ---
  static const String name = 'Full Name';
  static const String email = 'Email';
  static const String phone = 'Phone Number';
  static const String role = 'Role';
  static const String employeeId = 'Employee ID';
  static const String zone = 'Zone';
  static const String division = 'Division';
  static const String city = 'City';
  static const String address = 'Address';
  static const String location = 'Location';
  static const String getLocation = 'Get Location';
  static const String locationNotFetched = 'Not fetched';
  static const String fetchingLocation = 'Fetching location...';

  // --- Navigation ---
  static const String home = 'Home';
  static const String alerts = 'Alerts';
  static const String reports = 'Reports';

  // --- Error Messages ---
  static const String genericError = 'Something went wrong. Please try again.';
  static const String networkError = 'Network error. Please check your connection.';
  static const String sessionExpired = 'Session expired. Please login again.';
  static const String locationDenied = 'Location permission is required to create users.';

  // --- Edit / Delete User Strings ---
  static const String editUser = 'Edit User';
  static const String updatingUser = 'Updating user...';
  static const String userUpdated = 'User updated successfully!';
  static const String deleteUser = 'Delete User';
  static const String deletingUser = 'Deleting user...';
  static const String userDeleted = 'User deleted successfully!';
  static const String deleteConfirmTitle = 'Delete User';
  static const String deleteConfirmPrefix = 'Are you sure you want to delete';
  static const String deleteConfirmSuffix = '? This action cannot be undone.';
  static const String cancel = 'Cancel';
  static const String confirm = 'Confirm';
  static const String edit = 'Edit';
  static const String delete = 'Delete';

  // --- Hierarchy Tree Strings ---
  static const String hierarchyTree = 'Hierarchy Tree';
  static const String noHierarchyData = 'No hierarchy data available';

  // --- Division Dropdown Strings ---
  static const String selectDivision = 'Select Division';
  static const String selectZoneFirst = 'Select a zone first';
  static const String divisionComingSoon = 'Divisions coming soon';
  static const String selectCity = 'Select City';
  static const String selectDivisionFirst = 'Select a division first';
  static const String cityComingSoon = 'Cities coming soon';

  // --- Tab Labels ---
  static const String createUserTab = 'Create User';
  static const String hierarchyTreeTab = 'Hierarchy Tree';

  // --- Module 2: Registration ---
  static const String registerOperatorTitle = 'Operator Registration';
  static const String registerOperatorSubtitle = 'Join your division\'s relief crew';
  static const String registerAsOperator = 'Register as Operator';
  static const String noAccount = "Don't have an account? ";
  static const String registrationSuccess = 'Registration Submitted';
  static const String registrationSuccessMsg = 'Your registration is awaiting approval from your Lead Supervisor.';
  static const String backToLogin = 'Back to Login';
  
  // --- Module 2: Lead Supervisor ---
  static const String approvalQueue = 'Approval Queue';
  static const String notifications = 'Notifications';
  static const String approve = 'Approve';
  static const String reject = 'Reject';
  static const String rejectReason = 'Rejection Reason (Optional)';
  static const String noPendingOperators = 'No pending operators';
  static const String noNotifications = 'No notifications yet';

  // --- Module 2: ART Trains ---
  static const String artTrains = 'ART Trains';
  static const String createArtTrain = 'Create ART Train';
  static const String editArtTrain = 'Edit ART Train';
  static const String trainName = 'Train Name/Number';
  static const String depotLocation = 'Depot Location';
  static const String gpsDeviceId = 'GPS Device ID (Optional)';
  static const String selectSupervisor = 'Select Supervisor (Optional)';
  static const String noArtTrains = 'No ART Trains found';
  static const String noSupervisorsAvailable = 'No supervisors available';
  static const String assignedOperators = 'Assigned Operators';
  static const String addOperators = 'Add Operators';
  static const String noOperatorsAssigned = 'No operators assigned yet';
  static const String availableOperators = 'Available Operators';
  static const String reassign = 'Reassign';
  static const String remove = 'Remove';
  static const String forceAssign = 'Force Swap Supervisor';
  
  // --- Module 2: Supervisor & Operator Views ---
  static const String myArtTrain = 'My ART Train';
  static const String myAssignment = 'My Assignment';
  static const String noAssignment = 'You have not been assigned to an ART Train yet.';
  static const String trainSupervisor = 'Train Supervisor';

  // --- Module 3: Incident Management ---
  static const String incidents = 'Incidents';
  static const String createIncident = 'Create Incident';
  static const String incidentLog = 'Incident Log';
  static const String activeIncident = 'Active Incident';
  static const String resolveIncident = 'Resolve Incident';
  static const String mockDrill = 'Mock Drill';
  static const String severity = 'Severity';
  static const String trainNumber = 'Train Number';
  static const String incidentType = 'Incident Type';
  static const String affectedComponent = 'Affected Component';
  static const String selectCategory = 'Select Category';
  static const String selectSubcategory = 'Select Sub-category';
  static const String manualLocation = 'Manual Entry';
  static const String mapPicker = 'Map Picker';
  static const String incidentCreated = 'Incident created successfully!';
  static const String incidentResolved = 'Incident resolved.';
  static const String emergencyAlert = 'Emergency Alert';
  static const String acceptRespond = 'Accept & Respond';
  static const String decline = 'Decline';

  // --- Indian Railway Zones (19 zones) ---
  static const List<String> railwayZones = [
    'Central Railway',
    'Eastern Railway',
    'East Central Railway',
    'East Coast Railway',
    'Northern Railway',
    'North Central Railway',
    'North Eastern Railway',
    'Northeast Frontier Railway',
    'North Western Railway',
    'Southern Railway',
    'South Central Railway',
    'South Eastern Railway',
    'South East Central Railway',
    'South Western Railway',
    'Western Railway',
    'West Central Railway',
    'Metro Railway Kolkata',
    'Konkan Railway',
    'Dedicated Freight Corridor',
  ];
}
