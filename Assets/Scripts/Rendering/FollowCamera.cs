using UnityEngine;
using StickDrift.Car;

namespace StickDrift.Rendering
{
    /// <summary>
    /// Semi top-down chase cam. It turns to follow where the car is *going* (velocity), not where
    /// it's pointing, so during a drift you see the car swing sideways in front of you.
    /// </summary>
    public class FollowCamera : MonoBehaviour
    {
        public DriftCar car;
        [Range(30f, 89f)] public float pitch = 58f;
        public float distance = 22f;
        public float speedZoom = 0.18f;
        public float lookAhead = 0.35f;
        public float maxLookAhead = 8f;
        public float followSharpness = 6f;
        public float yawSharpness = 2.2f;
        [Tooltip("Off = fixed north-up camera like classic top-down drift games.")]
        public bool rotateWithCar = true;

        float yaw;
        Vector3 focus;

        void Start()
        {
            if (!car) return;
            yaw = car.transform.eulerAngles.y;
            focus = car.transform.position;
            Snap();
        }

        void LateUpdate()
        {
            if (!car) return;
            float dt = Time.deltaTime;
            var body = car.GetComponent<Rigidbody>();
            Vector3 v = body ? body.linearVelocity : Vector3.zero;
            v.y = 0f;

            Vector3 ahead = Vector3.ClampMagnitude(v * lookAhead, maxLookAhead);
            focus = Vector3.Lerp(focus, car.transform.position + ahead, 1f - Mathf.Exp(-followSharpness * dt));

            if (rotateWithCar)
            {
                float targetYaw = v.magnitude > 3f && car.ForwardSpeed > 0f
                    ? Quaternion.LookRotation(v).eulerAngles.y
                    : car.transform.eulerAngles.y;
                yaw = Mathf.LerpAngle(yaw, targetYaw, 1f - Mathf.Exp(-yawSharpness * dt));
            }
            else yaw = 0f;

            Snap(v.magnitude);
        }

        void Snap(float speed = 0f)
        {
            var rot = Quaternion.Euler(pitch, yaw, 0f);
            float d = distance + speed * speedZoom;
            transform.SetPositionAndRotation(focus - rot * Vector3.forward * d, rot);
        }
    }
}
