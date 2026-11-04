using System.Collections.Generic;
using UnityEngine;

namespace StickDrift.World
{
    /// <summary>
    /// Phones can only light a few pixels-lit lights at once, so only street lights near the car
    /// are switched on. The glowing light pools on the road stay on everywhere, so you can't tell.
    /// </summary>
    public class LampCuller : MonoBehaviour
    {
        public Transform target;
        public List<Light> lights = new List<Light>();
        public float radius = 55f;
        public float interval = 0.2f;

        float timer;

        void Update()
        {
            if (!target) return;
            timer -= Time.deltaTime;
            if (timer > 0f) return;
            timer = interval;

            Vector3 p = target.position;
            float r2 = radius * radius;
            foreach (var l in lights)
            {
                if (!l) continue;
                Vector3 d = l.transform.position - p;
                d.y = 0f;
                l.enabled = d.sqrMagnitude < r2;
            }
        }
    }
}
