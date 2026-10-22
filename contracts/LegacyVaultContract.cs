// SPDX-License-Identifier: MIT
// CONTRACT: LegacyVaultInheritance
// STATUS: DESIGNED, NOT DEPLOYED
// NOTE: Custom Forseti contract deployment requires Tide team review and network attestation.
// For the live hackathon prototype, Emergent Authority and plain threshold quorum (3-of-5 and 4-of-5)
// are enforced via TideCloak IGA and attested token roles. Any check done in application code
// is explicitly labelled [APP-LEVEL].

using System;
using System.Collections.Generic;

namespace Tide.Contracts
{
    /// <summary>
    /// Designed Forseti smart contract specifying multi-party inheritance release rules.
    /// In full deployment, this contract is compiled to WebAssembly/CIL and registered
    /// with the Tide ORK cluster to govern decentralized doken issuance.
    /// </summary>
    public class LegacyVaultContract
    {
        public const string VERSION = "1.0.0-designed";

        // Quorum thresholds
        public const int STANDARD_QUORUM = 3;  // 3-of-5 for standard assets & letters
        public const int CRITICAL_QUORUM = 4;  // 4-of-5 for crypto seed phrase
        public const int TOTAL_TRUSTEES = 5;

        public enum ItemCategory
        {
            PersonalLetter,
            RealEstateDeed,
            CryptoSeedPhrase
        }

        public class InheritanceRecord
        {
            public string ItemId { get; set; }
            public ItemCategory Category { get; set; }
            public string OwnerId { get; set; }
            public List<string> EligibleBeneficiaries { get; set; } = new List<string>();
            public HashSet<string> ApprovedTrustees { get; set; } = new HashSet<string>();
            public bool IsCancelledByOwner { get; set; } = false;
        }

        /// <summary>
        /// Evaluates whether an item is eligible for decentralized decryption.
        /// </summary>
        public bool CanDecrypt(InheritanceRecord record, string callerUserId, List<string> callerRoles)
        {
            // Safeguard: Owner cancellation terminates authority
            if (record.IsCancelledByOwner)
            {
                return false;
            }

            // Quorum threshold determination
            int requiredThreshold = (record.Category == ItemCategory.CryptoSeedPhrase)
                ? CRITICAL_QUORUM
                : STANDARD_QUORUM;

            // Quorum constraint: Must have strictly >= required valid trustee signatures
            if (record.ApprovedTrustees.Count < requiredThreshold)
            {
                return false;
            }

            // Beneficiary constraint: Caller must be in the designated recipient set
            if (!record.EligibleBeneficiaries.Contains(callerUserId))
            {
                return false;
            }

            return true;
        }
    }
}
