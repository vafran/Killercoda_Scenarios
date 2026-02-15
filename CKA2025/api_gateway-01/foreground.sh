#!/bin/bash
echo "Waiting for background setup to complete..."
while [ ! -f /tmp/background-finished ]; do sleep 1; done
echo "Setup complete! You can now start the scenario."
