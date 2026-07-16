const axios = require('axios');
const turf = require('@turf/turf');

/**
 * Get Operator to ART Train Navigation Route
 * GET /api/navigation/operator-to-art?operatorLat=&operatorLng=&artLat=&artLng=
 */
const getOperatorToArtRoute = async (req, res) => {
  try {
    const { operatorLat, operatorLng, artLat, artLng } = req.query;

    if (!operatorLat || !operatorLng || !artLat || !artLng) {
      return res.status(400).json({ success: false, message: 'Missing required coordinates.' });
    }

    const osrmUrl = `http://router.project-osrm.org/route/v1/driving/${operatorLng},${operatorLat};${artLng},${artLat}?overview=full&geometries=geojson`;
    
    try {
      const response = await axios.get(osrmUrl);
      
      if (response.data && response.data.routes && response.data.routes.length > 0) {
        const route = response.data.routes[0];
        const distanceKm = route.distance / 1000;
        const etaMinutes = Math.ceil(route.duration / 60);
        
        return res.status(200).json({
          success: true,
          routeGeoJSON: route.geometry,
          distanceKm,
          etaMinutes,
        });
      }
    } catch (osrmError) {
      console.error('OSRM API Error:', osrmError.message);
      // Fallback to Haversine if OSRM fails
    }

    // Fallback if OSRM fails or returns no route
    const from = turf.point([Number(operatorLng), Number(operatorLat)]);
    const to = turf.point([Number(artLng), Number(artLat)]);
    const distanceKm = turf.distance(from, to, { units: 'kilometers' }) * 1.3; // Road curve factor
    const etaMinutes = Math.ceil((distanceKm / 40) * 60); // 40 km/h average speed on road
    
    // Create a simple straight line geojson feature as fallback
    const fallbackGeoJSON = {
      type: "LineString",
      coordinates: [
        [Number(operatorLng), Number(operatorLat)],
        [Number(artLng), Number(artLat)]
      ]
    };

    res.status(200).json({
      success: true,
      routeGeoJSON: fallbackGeoJSON,
      distanceKm,
      etaMinutes,
      isFallback: true
    });

  } catch (error) {
    console.error('Get navigation route error:', error.message);
    res.status(500).json({ success: false, message: 'Internal server error.' });
  }
};

module.exports = {
  getOperatorToArtRoute,
};
