const express = require('express');
const cors = require('cors');
require('dotenv').config();

const app = express();

// Middleware
app.use(cors());
app.use(express.json());

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ ok: true, env: process.env.NODE_ENV || 'development' });
});

// TCRB Analytics Endpoints
app.get('/v1/analytics/ny/market-size', (req, res) => {
  // Mock data for NY cannabis market size
  const data = {
    series: [
      { year: 2021, value: 1.2 },
      { year: 2022, value: 2.8 },
      { year: 2023, value: 4.5 },
      { year: 2024, value: 6.2 },
      { year: 2025, value: 8.1 }
    ],
    currency: 'USD',
    units: 'billions',
    updatedAt: new Date().toISOString().split('T')[0]
  };
  res.json(data);
});

// Consumer Trust Survey Endpoints
app.get('/v1/surveys/consumer-trust', (req, res) => {
  const data = {
    items: [
      { factor: 'Product Transparency', importance: 9.2 },
      { factor: 'Lab Testing Results', importance: 8.9 },
      { factor: 'Brand Reputation', importance: 8.5 },
      { factor: 'Price Consistency', importance: 7.8 },
      { factor: 'Customer Service', importance: 7.4 }
    ],
    updatedAt: new Date().toISOString().split('T')[0]
  };
  res.json(data);
});

app.get('/v1/surveys/concerns-distribution', (req, res) => {
  const data = {
    items: [
      { label: 'Product Quality', pct: 35 },
      { label: 'Safety & Testing', pct: 28 },
      { label: 'Price Gouging', pct: 18 },
      { label: 'Availability', pct: 12 },
      { label: 'Legal Compliance', pct: 7 }
    ],
    updatedAt: new Date().toISOString().split('T')[0]
  };
  res.json(data);
});

// AI Answer Endpoint
app.post('/v1/ai/answer', (req, res) => {
  const { question } = req.body;
  
  if (!question) {
    return res.status(400).json({ error: 'Question is required' });
  }

  // Mock AI responses for common questions
  const responses = {
    'sativa indica difference': 'Sativa strains typically provide energizing, uplifting effects and are often associated with daytime use. Indica strains generally offer relaxing, calming effects and are better suited for evening use. However, individual responses can vary significantly.',
    'read label': 'NYS cannabis product labels must include: THC/CBD percentages, serving size, total servings, ingredients, testing lab info, and warnings. Always start with a low dose and wait to see effects.',
    'testing': 'All legal NYS cannabis products must be tested by licensed labs for potency, contaminants, and safety. Look for the testing lab information on the product label.',
    'safety': 'Purchase only from licensed dispensaries, start with low doses, avoid mixing with alcohol, and never drive under the influence. Store products safely away from children and pets.'
  };

  // Simple keyword matching for demo purposes
  let answer = 'As the TCRB AI, I can help with cannabis education questions. For specific medical advice, please consult a healthcare professional.';
  
  const questionLower = question.toLowerCase();
  for (const [key, response] of Object.entries(responses)) {
    if (questionLower.includes(key)) {
      answer = response;
      break;
    }
  }

  res.json({ answer });
});

module.exports = app;
