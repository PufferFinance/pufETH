#!/bin/sh

# Define the path to the pre-commit hook.
HOOK_PATH=".git/hooks/pre-commit"

# Check if the .git/hooks directory exists
if [ -d ".git/hooks" ]; then
  # Write the specified commands to the pre-commit hook
  cat > "$HOOK_PATH" << EOF
#!/bin/sh

# Run Slither
slither .

# Run Solhint for src and test directories
solhint src/*
solhint test/*

# Run Forge formatting
forge fmt
EOF

  # Make the pre-commit hook executable
  chmod +x "$HOOK_PATH"

  echo "Pre-commit hook has been installed successfully."
else
  echo "Error: This directory does not seem to be a Git repository."
fi
