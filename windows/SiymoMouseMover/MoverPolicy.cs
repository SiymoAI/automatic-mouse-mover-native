namespace SiymoMouseMover;
internal sealed class MoverPolicy
{
    public int IntervalSeconds { get; set; } = 60;
    public bool Enabled { get; private set; } = true;
    private long armedAt, lastMove;
    public void Reset(long now) { armedAt = now; lastMove = now; }
    public void SetEnabled(bool enabled, long now) { Enabled = enabled; Reset(now); }
    public void DidMove(long now) => lastMove = now;
    public bool ShouldMove(long now, double idle, bool available, bool buttonDown) =>
        Enabled && available && !buttonDown && double.IsFinite(idle) && idle >= IntervalSeconds
        && now - armedAt >= IntervalSeconds * 1000L && now - lastMove >= IntervalSeconds * 1000L;
}
