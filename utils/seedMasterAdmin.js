const bcrypt = require('bcryptjs');
const User = require('../models/User');

/**
 * Seed Master Admin on server startup
 * - If no master_admin exists: create one from .env credentials
 * - If master_admin exists: update if .env values differ (keep in sync)
 */
const seedMasterAdmin = async () => {
  try {
    const {
      MASTER_ADMIN_NAME,
      MASTER_ADMIN_EMAIL,
      MASTER_ADMIN_PHONE,
      MASTER_ADMIN_PASSWORD,
      MASTER_ADMIN_EMPLOYEE_ID,
    } = process.env;

    const existingAdmin = await User.findOne({ role: 'master_admin' });

    if (!existingAdmin) {
      // Create new master admin
      const hashedPassword = await bcrypt.hash(MASTER_ADMIN_PASSWORD, 12);

      await User.create({
        name: MASTER_ADMIN_NAME,
        email: MASTER_ADMIN_EMAIL.toLowerCase(),
        phone: MASTER_ADMIN_PHONE,
        role: 'master_admin',
        employee_id: MASTER_ADMIN_EMPLOYEE_ID,
        password: hashedPassword,
        isActive: true,
        createdBy: null,
      });

      console.log('✅ Master Admin created successfully');
    } else {
      // Check if any .env values differ from DB and update accordingly
      let needsUpdate = false;
      const updates = {};

      if (existingAdmin.name !== MASTER_ADMIN_NAME) {
        updates.name = MASTER_ADMIN_NAME;
        needsUpdate = true;
      }
      if (existingAdmin.email !== MASTER_ADMIN_EMAIL.toLowerCase()) {
        updates.email = MASTER_ADMIN_EMAIL.toLowerCase();
        needsUpdate = true;
      }
      if (existingAdmin.phone !== MASTER_ADMIN_PHONE) {
        updates.phone = MASTER_ADMIN_PHONE;
        needsUpdate = true;
      }
      if (existingAdmin.employee_id !== MASTER_ADMIN_EMPLOYEE_ID) {
        updates.employee_id = MASTER_ADMIN_EMPLOYEE_ID;
        needsUpdate = true;
      }

      // Check if password has changed
      const passwordMatch = await bcrypt.compare(
        MASTER_ADMIN_PASSWORD,
        existingAdmin.password
      );
      if (!passwordMatch) {
        updates.password = await bcrypt.hash(MASTER_ADMIN_PASSWORD, 12);
        needsUpdate = true;
      }

      if (needsUpdate) {
        await User.findByIdAndUpdate(existingAdmin._id, updates);
        console.log('✅ Master Admin updated from .env values');
      } else {
        console.log('ℹ️  Master Admin already exists and is up to date');
      }
    }
  } catch (error) {
    console.error(`❌ Error seeding Master Admin: ${error.message}`);
  }
};

module.exports = seedMasterAdmin;
