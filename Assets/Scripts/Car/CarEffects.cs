using UnityEngine;

namespace StickDrift.Car
{
    /// <summary>Visual feedback: steering front wheels, skid marks, tire smoke, engine smoke, brake lights.</summary>
    public class CarEffects : MonoBehaviour
    {
        public DriftCar car;
        public Transform frontLeftPivot, frontRightPivot;
        public TrailRenderer[] skids;
        public ParticleSystem[] tireSmoke;
        public ParticleSystem engineSmoke;
        public Material tailLights;
        public Color tailColor = new Color(1f, 0.08f, 0.05f);

        void Update()
        {
            if (!car) return;

            var steer = Quaternion.Euler(0f, car.SteerAngle, 0f);
            if (frontLeftPivot) frontLeftPivot.localRotation = steer;
            if (frontRightPivot) frontRightPivot.localRotation = steer;

            bool sliding = car.SpeedMps > 2f && (car.RearSlide > 0.15f || car.IsDrifting || car.Handbrake > 0.5f);
            foreach (var s in skids)
                if (s) s.emitting = sliding;

            float smokeRate = sliding ? 25f + car.RearSlide * 70f : 0f;
            foreach (var ps in tireSmoke)
            {
                if (!ps) continue;
                var em = ps.emission;
                em.rateOverTime = smokeRate;
            }

            if (engineSmoke)
            {
                var em = engineSmoke.emission;
                em.rateOverTime = car.engine.Blown ? 45f : car.engine.Health < 0.35f ? 10f : 0f;
            }

            if (tailLights)
            {
                bool braking = car.Handbrake > 0.1f || car.Gear == Gearbox.Neutral;
                tailLights.SetColor("_EmissionColor", tailColor * (braking ? 4.5f : 1.3f));
            }
        }
    }
}
