const functions = require("firebase-functions");
const { GoogleGenerativeAI } = require("@google/generative-ai");

exports.askFarmMitra = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "User must be logged in to ask questions.");
  }

  const question = data.question;
  const history = data.history || []; 

  if (!question) {
    throw new functions.https.HttpsError("invalid-argument", "Question is required.");
  }

  try {
    // SECURITY: Get the API key from the environment variables securely.
    // Ensure you have set GEMINI_API_KEY in your Cloud Functions environment.
    const apiKey = process.env.GEMINI_API_KEY || "YOUR_API_KEY_HERE";
    const genAI = new GoogleGenerativeAI(apiKey);
    
    const model = genAI.getGenerativeModel({ 
        model: "gemini-3.6-flash",
        systemInstruction: "You are Farm Mitra, a helpful agriculture AI assistant. You answer farming questions accurately and in a simple, farmer-friendly manner. YOU MUST ALWAYS RESPOND IN ENGLISH, NO MATTER WHAT LANGUAGE THE USER ASKS IN. If uncertain, clearly state it."
    });

    const chat = model.startChat({
        history: history,
    });

    const result = await chat.sendMessage(question);
    const responseText = result.response.text();
    
    return { answer: responseText };
  } catch (error) {
    console.error("AI Error:", error);
    throw new functions.https.HttpsError("internal", "Failed to get AI response.");
  }
});
