# Project Tahoe X86 — Security Model

- **Purpose**: Define trust boundaries, credential handling, and permission model
- **Status**: Draft

## 1. Threat Model Summary

The platform must protect:

- User secrets, especially OAuth tokens and keyring data
- Local files and metadata
- Assistant tool execution and prompt content
- UI state against impossible or misleading feedback
- Installation and update paths

It runs on a general-purpose OS, so it must not weaken Linux security mechanisms just to simplify implementation.

## 2. Credential Handling

- Passwords must be hashed with appropriate password-hashing algorithms; never stored in plaintext
- OAuth tokens and other secrets must be stored in a Secret Service-compatible keyring
- Secrets must not live in source code, ordinary config files, logs, or AI prompts
- Token refresh must be handled without exposing tokens to the assistant or to logs

## 3. Cloud Authorization

- Cloud access requires explicit user authorization
- Google Drive must use OAuth 2.0 with the appropriate native-app flow
- Users must not be asked to type passwords into an imitation Google login screen
- Revocation and disconnection must be possible from System Settings or the cloud provider UI

## 4. Assistant Tool Execution

- The assistant must not receive unrestricted shell access
- Tool execution uses a typed registry with schemas, validation, authorization, and structured results
- High-impact actions require explicit confirmation
- Prompt-injected document or web content must not bypass authorization

## 5. File Operations

- File operations must use the real filesystem
- Safe operations must be preferred over silent overwrites
- Destructive operations require clear confirmation
- Trash and restore must be real, not cosmetic

## 6. Privileged Operations

- Settings that need elevated privileges must go through an authorized service with user consent
- The UI must not run privileged commands from untrusted text
- Capability-dependent settings must be shown honestly

## 7. Privacy

- Assistant history and logs need privacy controls
- Local documents should not be sent to remote AI providers unless the user explicitly enables that
- Network requests should be limited to what is required

## 8. Distribution and Updates

- Build artifacts should be verifiable where practical
- Updates should have safe install and rollback behavior
- Installation must not perform destructive disk operations without explicit consent

## 9. Testing Security Properties

- Credential storage paths must be verified
- Tool authorization must be tested
- Cloud error handling must be honest
- Local AI must run without a remote provider
- Unauthorized assistant actions must be rejected

