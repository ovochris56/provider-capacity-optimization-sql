import pandas as pd
import numpy as np
import random
from datetime import datetime, timedelta
import os

# -----------------------------
# SETTINGS
# -----------------------------
np.random.seed(42)
random.seed(42)

save_path = os.path.join(
    os.path.expanduser("~/Desktop"),
    "capacity-optimization"
)

os.makedirs(save_path, exist_ok=True)

# -----------------------------
# 1. LOCATIONS
# -----------------------------
locations = pd.DataFrame({
    "location_id": [1, 2, 3],
    "location_name": [
        "Providence Specialty Clinic",
        "Warwick Outpatient Center",
        "Pawtucket Community Health"
    ],
    "city": ["Providence", "Warwick", "Pawtucket"],
    "state": ["RI", "RI", "RI"]
})

# -----------------------------
# 2. PROVIDERS
# -----------------------------
providers = pd.DataFrame({
    "provider_id": range(1, 13),
    "provider_name": [
        "Dr. Elena Torres", "Dr. Marcus Reed", "Dr. Priya Shah",
        "Dr. David Kim", "Dr. Sofia Mendes", "Dr. Andre Baptiste",
        "Dr. Hannah Blake", "Dr. Miguel Santos", "Dr. Rachel Nguyen",
        "Dr. James Carter", "Dr. Leila Hassan", "Dr. Thomas Avery"
    ],
    "specialty": [
        "Primary Care", "Cardiology", "Endocrinology",
        "Orthopedics", "Behavioral Health", "Physical Therapy",
        "Primary Care", "Cardiology", "Endocrinology",
        "Orthopedics", "Behavioral Health", "Physical Therapy"
    ],
    "location_id": [1, 1, 1, 2, 2, 2, 3, 3, 3, 1, 3, 1],
    "fte": [1.0, 0.8, 0.75, 1.0, 0.8, 1.0, 1.0, 0.7, 0.8, 0.9, 0.75, 1.0],
    "weekly_available_hours": [40, 32, 30, 40, 32, 40, 40, 28, 32, 36, 30, 40]
})

# -----------------------------
# 3. PATIENTS
# -----------------------------
n_patients = 500

patients = pd.DataFrame({
    "patient_id": range(1, n_patients + 1),
    "age_group": np.random.choice(
        ["18-34", "35-49", "50-64", "65+"],
        size=n_patients,
        p=[0.25, 0.30, 0.25, 0.20]
    ),
    "insurance_type": np.random.choice(
        ["Commercial", "Medicare", "Medicaid", "Self-Pay"],
        size=n_patients,
        p=[0.45, 0.25, 0.25, 0.05]
    ),
    "language_preference": np.random.choice(
        ["English", "Spanish", "Portuguese", "Cape Verdean Creole"],
        size=n_patients,
        p=[0.70, 0.15, 0.10, 0.05]
    ),
    "risk_level": np.random.choice(
        ["Low", "Medium", "High"],
        size=n_patients,
        p=[0.50, 0.35, 0.15]
    )
})

# -----------------------------
# 4. PROVIDER AVAILABILITY
# -----------------------------
start_date = datetime(2025, 1, 1)
end_date = datetime(2025, 6, 30)

dates = pd.date_range(start_date, end_date, freq="B")

availability_rows = []
availability_id = 1

for _, provider in providers.iterrows():
    daily_minutes = int((provider["weekly_available_hours"] * 60) / 5)

    for d in dates:
        available_minutes = 0 if np.random.random() < 0.05 else daily_minutes

        availability_rows.append({
            "availability_id": availability_id,
            "provider_id": provider["provider_id"],
            "availability_date": d.date(),
            "available_minutes": available_minutes
        })

        availability_id += 1

provider_availability = pd.DataFrame(availability_rows)

# -----------------------------
# 5. APPOINTMENTS
# -----------------------------
specialty_to_providers = (
    providers.groupby("specialty")["provider_id"]
    .apply(list)
    .to_dict()
)

appointment_types = {
    "Primary Care": ["Annual Visit", "Follow-up", "Urgent Visit"],
    "Cardiology": ["New Consult", "Follow-up", "Testing Review"],
    "Endocrinology": ["New Consult", "Diabetes Follow-up", "Medication Review"],
    "Orthopedics": ["New Injury", "Follow-up", "Post-op Visit"],
    "Behavioral Health": ["Therapy Session", "Medication Management", "Intake"],
    "Physical Therapy": ["Initial Evaluation", "Follow-up Treatment", "Discharge Visit"]
}

duration_map = {
    "Annual Visit": 30,
    "Follow-up": 20,
    "Urgent Visit": 20,
    "New Consult": 45,
    "Testing Review": 30,
    "Diabetes Follow-up": 30,
    "Medication Review": 20,
    "New Injury": 30,
    "Post-op Visit": 30,
    "Therapy Session": 50,
    "Medication Management": 30,
    "Intake": 60,
    "Initial Evaluation": 45,
    "Follow-up Treatment": 30,
    "Discharge Visit": 30
}

specialty_demand_weights = {
    "Primary Care": 0.28,
    "Behavioral Health": 0.20,
    "Physical Therapy": 0.18,
    "Orthopedics": 0.14,
    "Cardiology": 0.11,
    "Endocrinology": 0.09
}

specialties = list(specialty_demand_weights.keys())
weights = list(specialty_demand_weights.values())

appointment_rows = []
appointment_id = 1
n_appointments = 2600

for _ in range(n_appointments):
    specialty = np.random.choice(specialties, p=weights)
    provider_id = np.random.choice(specialty_to_providers[specialty])
    patient_id = np.random.randint(1, n_patients + 1)

    appointment_date = pd.to_datetime(np.random.choice(dates))

    if specialty == "Behavioral Health":
        lead_days = np.random.randint(21, 75)
    elif specialty == "Endocrinology":
        lead_days = np.random.randint(18, 60)
    elif specialty == "Cardiology":
        lead_days = np.random.randint(14, 45)
    else:
        lead_days = np.random.randint(3, 35)

    scheduled_date = appointment_date - timedelta(days=int(lead_days))

    appt_type = np.random.choice(appointment_types[specialty])
    duration = duration_map[appt_type]

    patient = patients.loc[patients["patient_id"] == patient_id].iloc[0]

    no_show_prob = 0.08
    cancel_prob = 0.10

    if patient["insurance_type"] == "Medicaid":
        no_show_prob += 0.05

    if patient["age_group"] == "18-34":
        no_show_prob += 0.03

    if appointment_date.weekday() in [0, 4]:
        no_show_prob += 0.02

    if specialty == "Behavioral Health":
        no_show_prob += 0.03

    if specialty == "Orthopedics":
        cancel_prob += 0.04

    status = np.random.choice(
        ["Completed", "No-Show", "Cancelled"],
        p=[
            1 - no_show_prob - cancel_prob,
            no_show_prob,
            cancel_prob
        ]
    )

    appointment_rows.append({
        "appointment_id": appointment_id,
        "patient_id": patient_id,
        "provider_id": provider_id,
        "appointment_date": appointment_date.date(),
        "scheduled_date": scheduled_date.date(),
        "appointment_type": appt_type,
        "status": status,
        "duration_minutes": duration
    })

    appointment_id += 1

appointments = pd.DataFrame(appointment_rows)

# -----------------------------
# 6. REFERRALS
# -----------------------------
referral_rows = []
referral_id = 1
n_referrals = 800

priority_wait_targets = {
    "Routine": 45,
    "Priority": 21,
    "Urgent": 7
}

for _ in range(n_referrals):
    patient_id = np.random.randint(1, n_patients + 1)
    specialty = np.random.choice(specialties, p=weights)

    possible_locations = providers[
        providers["specialty"] == specialty
    ]["location_id"].unique()

    location_id = np.random.choice(possible_locations)

    referral_date = start_date + timedelta(days=np.random.randint(0, 181))

    priority_level = np.random.choice(
        ["Routine", "Priority", "Urgent"],
        p=[0.65, 0.25, 0.10]
    )

    appointment_needed_by = referral_date + timedelta(
        days=priority_wait_targets[priority_level]
    )

    referral_rows.append({
        "referral_id": referral_id,
        "patient_id": patient_id,
        "specialty": specialty,
        "location_id": location_id,
        "referral_date": referral_date.date(),
        "priority_level": priority_level,
        "appointment_needed_by": appointment_needed_by.date()
    })

    referral_id += 1

referrals = pd.DataFrame(referral_rows)

# -----------------------------
# EXPORT CSVs
# -----------------------------
locations.to_csv(os.path.join(save_path, "locations.csv"), index=False)
providers.to_csv(os.path.join(save_path, "providers.csv"), index=False)
patients.to_csv(os.path.join(save_path, "patients.csv"), index=False)
provider_availability.to_csv(os.path.join(save_path, "provider_availability.csv"), index=False)
appointments.to_csv(os.path.join(save_path, "appointments.csv"), index=False)
referrals.to_csv(os.path.join(save_path, "referrals.csv"), index=False)

# -----------------------------
# SUCCESS CHECKS
# -----------------------------
print("Synthetic data generated successfully.")
print("\nFiles saved to:")
print(save_path)

print("\nFiles created:")
print(os.listdir(save_path))

print("\nAppointments shape:")
print(appointments.shape)

print("\nAppointment status distribution:")
print(appointments["status"].value_counts(normalize=True).round(3))