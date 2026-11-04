using System;
using UnityEngine;

namespace StickDrift.Car
{
    /// <summary>
    /// Arcade drift physics on a flat plane (bicycle model: one front axle, one rear axle).
    /// Unity's WheelColliders are notoriously hard to make drift nicely, so this does the tire
    /// forces by hand: each axle has a grip budget, and the rear axle shares its budget between
    /// drive force and side grip (friction circle). Too much power or the handbrake = rear steps out.
    /// </summary>
    [RequireComponent(typeof(Rigidbody))]
    public class DriftCar : MonoBehaviour
    {
        public CarControls controls;

        [Header("Drivetrain")]
        public Engine engine = new Engine();
        public float wheelRadius = 0.3f;
        public float finalDrive = 4.3f;
        [Tooltip("Arcade boost on engine torque. Raise for more power oversteer.")]
        public float torqueMultiplier = 1.15f;

        [Header("Chassis")]
        public float frontAxleZ = 1.25f;
        public float rearAxleZ = -1.2f;
        public float maxSteerAngle = 42f;
        [Tooltip("Degrees per second the front wheels can turn.")]
        public float steerSpeed = 260f;

        [Header("Tires")]
        public float frontGrip = 1.15f;
        public float rearGrip = 1.0f;
        [Tooltip("Rear keeps at least this much side grip even at full wheelspin, so drifts stay catchable.")]
        [Range(0f, 1f)] public float minRearLateralShare = 0.3f;
        [Range(0f, 1f)] public float handbrakeGripScale = 0.35f;
        public float handbrakeBrake = 0.9f;

        [Header("Resistance")]
        [Tooltip("m/s^2 of rolling resistance.")]
        public float rollingResistance = 0.25f;
        public float aeroDrag = 0.42f;
        [Tooltip("Extra m/s^2 of slowdown in neutral (or with a dead engine) so stopping isn't floaty.")]
        public float coastBrake = 3.2f;

        public int Gear { get; private set; }
        public float SteerAngle { get; private set; }
        public float SpeedMps { get; private set; }
        public float ForwardSpeed { get; private set; }
        public float SlipAngle { get; private set; }
        public float RearSlide { get; private set; }
        public float FrontSlide { get; private set; }
        public float WheelspinRpm { get; private set; }
        public bool IsDrifting { get; private set; }
        public float Handbrake => controls ? controls.Handbrake : 0f;

        public event Action<int, int> GearChanged;
        public event Action EngineBlown;

        const float G = 9.81f;
        const float RadPerSecToRpm = 60f / (2f * Mathf.PI);

        Rigidbody rb;
        Vector3 spawnPos;
        Quaternion spawnRot;
        bool wasBlown;

        void Awake()
        {
            rb = GetComponent<Rigidbody>();
            spawnPos = transform.position;
            spawnRot = transform.rotation;
            engine.Repair();
        }

        void FixedUpdate()
        {
            float dt = Time.fixedDeltaTime;

            // Gear comes straight from the shifter (clutchless).
            int requested = controls ? controls.Gear : 0;
            if (requested != Gear)
            {
                int old = Gear;
                Gear = requested;
                GearChanged?.Invoke(old, Gear);
            }

            float targetSteer = (controls ? controls.Steer : 0f) * maxSteerAngle;
            SteerAngle = Mathf.MoveTowards(SteerAngle, targetSteer, steerSpeed * dt);

            Vector3 fwd = transform.forward;
            Vector3 right = transform.right;
            Vector3 v = rb.linearVelocity;
            v.y = 0f;
            float vF = Vector3.Dot(v, fwd);
            ForwardSpeed = vF;
            SpeedMps = v.magnitude;

            // ---- Engine ----
            float ratio = Gearbox.Ratio(Gear) * finalDrive;
            bool engaged = Gear != Gearbox.Neutral && !engine.Blown;
            float groundRpm = Mathf.Abs(vF / wheelRadius * ratio) * RadPerSecToRpm;
            engine.Tick(groundRpm + WheelspinRpm, engaged, dt);
            if (engine.Blown && !wasBlown)
            {
                wasBlown = true;
                EngineBlown?.Invoke();
            }

            float axleMass = rb.mass * 0.5f;
            float frontMax = frontGrip * G * axleMass;
            float rearMax = rearGrip * G * axleMass;
            float hb = Handbrake;
            rearMax *= Mathf.Lerp(1f, handbrakeGripScale, hb);

            // Throttle is always on. Drive force comes from the torque curve, which goes negative
            // past the cutoff (engine braking after a downshift).
            float drive = 0f;
            if (engaged)
            {
                bool againstGear = vF * Mathf.Sign(ratio) < -0.5f;
                if (againstGear)
                    drive = -Mathf.Sign(vF) * rearMax * 0.9f; // e.g. slammed into R while rolling forward
                else
                    drive = engine.TorqueAt(engine.Rpm) * torqueMultiplier * ratio / wheelRadius;
                drive *= Mathf.Lerp(1f, 0.25f, hb);
            }

            // Stiffness that would cancel sideways speed in ~2 physics steps.
            float lateralStiffness = axleMass / dt * 0.5f;

            // ---- Front axle ----
            Vector3 frontPos = transform.TransformPoint(0f, 0f, frontAxleZ);
            Vector3 fFwd = Quaternion.AngleAxis(SteerAngle, Vector3.up) * fwd;
            Vector3 fRight = Vector3.Cross(Vector3.up, fFwd);
            float fLat = Vector3.Dot(rb.GetPointVelocity(frontPos), fRight);
            float fWant = -fLat * lateralStiffness;
            float fForce = Mathf.Clamp(fWant, -frontMax, frontMax);
            FrontSlide = Mathf.Abs(fWant) > frontMax ? Mathf.Clamp01(Mathf.Abs(fLat) / 5f) : 0f;
            rb.AddForceAtPosition(fRight * fForce, frontPos, ForceMode.Force);

            // ---- Rear axle (drive + handbrake + friction circle) ----
            Vector3 rearPos = transform.TransformPoint(0f, 0f, rearAxleZ);
            Vector3 rv = rb.GetPointVelocity(rearPos);
            float rLat = Vector3.Dot(rv, right);
            float rLong = Vector3.Dot(rv, fwd);

            float longF = Mathf.Clamp(drive, -rearMax, rearMax);
            float spinExcess = Mathf.Max(0f, Mathf.Abs(drive) - rearMax) / Mathf.Max(rearMax, 1f);

            if (hb > 0.01f)
            {
                float brake = Mathf.Min(Mathf.Abs(rLong) * axleMass / dt * 0.5f, handbrakeBrake * rearMax * hb);
                longF = Mathf.Clamp(longF - Mathf.Sign(rLong) * brake, -rearMax, rearMax);
            }

            float latAvail = Mathf.Sqrt(Mathf.Max(0f, rearMax * rearMax - longF * longF));
            latAvail = Mathf.Max(latAvail, rearMax * minRearLateralShare);
            float rWant = -rLat * lateralStiffness;
            float rForce = Mathf.Clamp(rWant, -latAvail, latAvail);
            bool rearSliding = Mathf.Abs(rWant) > latAvail;
            RearSlide = Mathf.Max(rearSliding ? Mathf.Clamp01(Mathf.Abs(rLat) / 5f) : 0f, Mathf.Clamp01(spinExcess));
            rb.AddForceAtPosition(fwd * longF + right * rForce, rearPos, ForceMode.Force);

            // Wheelspin pushes the tach up while you're sliding, which is how drifting can cook the engine.
            float spinTarget = engaged ? Mathf.Clamp01(spinExcess) * 2200f + RearSlide * 900f : 0f;
            WheelspinRpm = Mathf.MoveTowards(WheelspinRpm, spinTarget, 6000f * dt);

            // ---- Rolling resistance, drag, neutral coast brake ----
            if (SpeedMps > 0.01f)
            {
                Vector3 dir = v / SpeedMps;
                float resist = rollingResistance * rb.mass + aeroDrag * SpeedMps * SpeedMps;
                if (!engaged) resist += coastBrake * rb.mass;
                resist = Mathf.Min(resist, SpeedMps * rb.mass / dt);
                rb.AddForce(-dir * resist, ForceMode.Force);
            }

            // ---- Drift state ----
            if (SpeedMps > 3f && vF > 0f)
            {
                SlipAngle = Vector3.SignedAngle(fwd, v, Vector3.up);
                IsDrifting = SpeedMps > 5f && Mathf.Abs(SlipAngle) > 12f;
            }
            else
            {
                SlipAngle = 0f;
                IsDrifting = false;
            }
        }

        public void RepairEngine()
        {
            engine.Repair();
            wasBlown = false;
            WheelspinRpm = 0f;
        }

        public void ResetToSpawn()
        {
            rb.linearVelocity = Vector3.zero;
            rb.angularVelocity = Vector3.zero;
            rb.position = spawnPos;
            rb.rotation = spawnRot;
            transform.SetPositionAndRotation(spawnPos, spawnRot);
            SteerAngle = 0f;
            RepairEngine();
        }
    }
}
