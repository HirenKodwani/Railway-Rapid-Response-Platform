/**
 * Role-Based Access Control (RBAC) Middleware Factory
 * Returns middleware that checks if req.user.role is in the allowed roles list
 *
 * Usage:
 *   router.post('/create', auth, rbac(['master_admin', 'super_admin']), controller)
 */
const rbac = (allowedRoles) => {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({
        success: false,
        message: 'Authentication required before role check.',
      });
    }

    if (!allowedRoles.includes(req.user.role)) {
      return res.status(403).json({
        success: false,
        message: `Access denied. Role '${req.user.role}' is not authorized for this action.`,
      });
    }

    next();
  };
};

module.exports = rbac;
