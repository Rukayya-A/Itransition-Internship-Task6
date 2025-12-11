import time
import psycopg
import os

# Read connection string from environment variable
DATABASE_URL = os.environ.get("DATABASE_URL")

def run_benchmark(user_counts, locale="en_US", seed=12345):
    results = []
    with psycopg.connect(DATABASE_URL) as conn:
        with conn.cursor() as cur:
            for count in user_counts:
                print(f"Generating {count} users...")
                
                start = time.time()
                # Call your SQL generator: (locale, seed, total_users)
                cur.execute(
                    "SELECT generate_fake_users(%s, %s, %s);",
                    (locale, seed, count)
                )
                conn.commit()
                
                elapsed = time.time() - start
                throughput = count / elapsed

                results.append((count, elapsed, throughput))
                print(f"  Time: {elapsed:.2f}s, Throughput: {throughput:.0f} users/s")

    return results


if __name__ == "__main__":
    # Your test batch sizes (local test)
    user_counts = [10_000, 50_000, 100_000, 500_000, 1_000_000]

    results = run_benchmark(user_counts)

    print("\nBenchmark Results (Local Machine)")
    print("Batch Size | Time (s) | Throughput (users/s)")
    for count, elapsed, throughput in results:
        print(f"{count:10} | {elapsed:7.2f} | {throughput:10.0f}")
