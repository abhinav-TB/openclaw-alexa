import logging
import os
import requests

from ask_sdk_core.skill_builder import SkillBuilder
from ask_sdk_core.dispatch_components import AbstractRequestHandler
from ask_sdk_core.dispatch_components import AbstractExceptionHandler
from ask_sdk_core.utils import is_request_type, is_intent_name
from ask_sdk_core.handler_input import HandlerInput

from ask_sdk_model import Response

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

# Configuration: Hardcode these here since Alexa-Hosted Skills UI doesn't natively support EnvVars easily
OPENCLAW_URL = "https://YOUR_FORWARDING_URL.ngrok-free.app/hooks/agent" # Or use Tailscale URL
OPENCLAW_TOKEN = "YOUR_NEW_PRACTICALLY_UNGUESSABLE_TOKEN"
DELIVERY_DESTINATION = "YOUR_DELIVERY_DESTINATION_HERE"
DELIVERY_CHANNEL = "telegram" # Change to "alexacli" for asynchronous voice responses

class LaunchRequestHandler(AbstractRequestHandler):
    """Handler for Skill Launch."""
    def can_handle(self, handler_input):
        return is_request_type("LaunchRequest")(handler_input)

    def handle(self, handler_input):
        speak_output = "Open claw is ready. What would you like to do?"
        return (
            handler_input.response_builder
                .speak(speak_output)
                .ask(speak_output)
                .response
        )

class PassThroughIntentHandler(AbstractRequestHandler):
    """Handler for PassThroughIntent (AMAZON.SearchQuery)."""
    def can_handle(self, handler_input):
        return is_intent_name("PassThroughIntent")(handler_input)

    def handle(self, handler_input):
        slots = handler_input.request_envelope.request.intent.slots
        user_query = slots["Query"].value if slots and "Query" in slots and slots.get("Query") and slots["Query"].value else None
        
        if not user_query:
            speak_output = "I didn't catch that. Could you repeat?"
            return handler_input.response_builder.speak(speak_output).ask(speak_output).response

        try:
            # Send the transcribed text to OpenClaw via Webhook
            headers = {
                "Authorization": f"Bearer {OPENCLAW_TOKEN}",
                "Content-Type": "application/json"
            } if OPENCLAW_TOKEN else {"Content-Type": "application/json"}
            
            payload = {
                "message": user_query,
                "deliver": True,
                "channel": DELIVERY_CHANNEL,
                "to": DELIVERY_DESTINATION
            }
            
            logger.info(f"Sending prompt to OpenClaw Webhook: {user_query}")
            
            # Alexa times out after 8 seconds, so we set a timeout of 6 seconds
            response = requests.post(OPENCLAW_URL, json=payload, headers=headers, timeout=6.0)
            
            if response.status_code == 200:
                data = response.json()
                if "runId" in data:
                    speak_output = "I have sent your request to AI Claw! It will message you when finished."
                else:
                    speak_output = data.get("response", data.get("text", "I received a synchronous response but couldn't parse the text."))
            else:
                speak_output = f"Open claw returned an error: HTTP {response.status_code}."
                
        except requests.exceptions.Timeout:
            speak_output = "Open claw took too long to respond."
        except Exception as e:
            logger.error(f"Error communicating with OpenClaw: {e}")
            speak_output = "I had trouble connecting to your Open Claw gateway. Is ngrok running?"

        # Keep session open so user can keep talking without saying 'Alexa' again
        return (
            handler_input.response_builder
                .speak(speak_output)
                .set_should_end_session(False)
                .response
        )

class FallbackIntentHandler(AbstractRequestHandler):
    """Handler for Fallback Intent."""
    def can_handle(self, handler_input):
        return is_intent_name("AMAZON.FallbackIntent")(handler_input)

    def handle(self, handler_input):
        speak_output = "I didn't quite catch that. You must use a carrier phrase like 'to' or 'can you'. Try saying 'to check the servers'."
        return (
            handler_input.response_builder
                .speak(speak_output)
                .ask(speak_output)
                .response
        )

class CancelOrStopIntentHandler(AbstractRequestHandler):
    """Single handler for Cancel and Stop Intent."""
    def can_handle(self, handler_input):
        return (is_intent_name("AMAZON.CancelIntent")(handler_input) or
                is_intent_name("AMAZON.StopIntent")(handler_input))

    def handle(self, handler_input):
        speak_output = "Closing Open claw."
        return (
            handler_input.response_builder
                .speak(speak_output)
                .response
        )

class SessionEndedRequestHandler(AbstractRequestHandler):
    """Handler for Session End."""
    def can_handle(self, handler_input):
        return is_request_type("SessionEndedRequest")(handler_input)

    def handle(self, handler_input):
        logger.info(f"Session ended with reason: {handler_input.request_envelope.request.reason}")
        return handler_input.response_builder.response

class CatchAllExceptionHandler(AbstractExceptionHandler):
    """Catch all exception handler."""
    def can_handle(self, handler_input, exception):
        return True

    def handle(self, handler_input, exception):
        logger.error(exception, exc_info=True)
        speak_output = "Sorry, I had trouble doing what you asked. Please try again."
        return (
            handler_input.response_builder
                .speak(speak_output)
                .ask(speak_output)
                .response
        )

# Construct the Skill Builder
sb = SkillBuilder()
sb.add_request_handler(LaunchRequestHandler())
sb.add_request_handler(PassThroughIntentHandler())
sb.add_request_handler(FallbackIntentHandler())
sb.add_request_handler(CancelOrStopIntentHandler())
sb.add_request_handler(SessionEndedRequestHandler())
sb.add_exception_handler(CatchAllExceptionHandler())

# This is the entry point for AWS Lambda
lambda_handler = sb.lambda_handler()
