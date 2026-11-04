using UnityEngine;

namespace StickDrift.Car
{
    /// <summary>
    /// Simple engine model. The throttle is always on, so the only ways to keep it alive are:
    /// shift up before it sits on the limiter, and don't downshift so hard that it over-revs.
    /// Past the torque cutoff the curve goes negative, which gives you engine braking on downshifts.
    /// </summary>
    [System.Serializable]
    public class Engine
    {
        public float idleRpm = 900f;
        [Tooltip("Where the tach turns red and the SHIFT warning starts.")]
        public float redlineRpm = 7600f;
        public float peakTorque = 150f;

        [Header("Damage")]
        [Tooltip("Above this, the engine slowly takes damage (sitting on the limiter).")]
        public float damageRpm = 7900f;
        [Tooltip("Damage per second for every 1000 rpm above damageRpm.")]
        public float sustainedDamage = 0.6f;
        [Tooltip("Above this you've money-shifted. Damage ramps up hard.")]
        public float moneyShiftRpm = 9400f;
        [Tooltip("Extra damage per second for every 1000 rpm above moneyShiftRpm.")]
        public float moneyShiftDamage = 2.5f;

        public float Rpm { get; private set; }
        public float Health { get; private set; } = 1f;
        public bool Blown => Health <= 0f;
        public bool OverRedline => Rpm > redlineRpm;

        // Normalized torque curve (x = rpm, y = fraction of peak torque).
        static readonly Vector2[] Curve =
        {
            new Vector2(0f, 0.50f),
            new Vector2(1000f, 0.55f),
            new Vector2(3000f, 0.80f),
            new Vector2(5200f, 1.00f),
            new Vector2(6600f, 0.95f),
            new Vector2(7600f, 0.80f),
            new Vector2(8000f, 0.20f),
            new Vector2(8400f, -0.40f),
            new Vector2(9400f, -1.00f),
            new Vector2(13000f, -1.30f),
        };

        public float TorqueAt(float rpm)
        {
            if (rpm <= Curve[0].x) return Curve[0].y * peakTorque;
            for (int i = 1; i < Curve.Length; i++)
            {
                if (rpm <= Curve[i].x)
                {
                    float t = Mathf.InverseLerp(Curve[i - 1].x, Curve[i].x, rpm);
                    return Mathf.Lerp(Curve[i - 1].y, Curve[i].y, t) * peakTorque;
                }
            }
            return Curve[Curve.Length - 1].y * peakTorque;
        }

        /// <param name="targetRpm">What the wheels say the engine should be spinning at.</param>
        /// <param name="engaged">True when in gear (clutchless, so rpm locks straight to the wheels).</param>
        public void Tick(float targetRpm, bool engaged, float dt)
        {
            if (Blown)
            {
                Rpm = Mathf.MoveTowards(Rpm, 0f, 4000f * dt);
                return;
            }

            if (engaged) Rpm = Mathf.Max(idleRpm, targetRpm);
            else Rpm = Mathf.MoveTowards(Rpm, idleRpm, 5000f * dt);

            float damage = 0f;
            if (Rpm > damageRpm) damage += sustainedDamage * (Rpm - damageRpm) / 1000f * dt;
            if (Rpm > moneyShiftRpm) damage += moneyShiftDamage * (Rpm - moneyShiftRpm) / 1000f * dt;
            Health = Mathf.Max(0f, Health - damage);
        }

        public void Repair()
        {
            Health = 1f;
            Rpm = idleRpm;
        }
    }
}
