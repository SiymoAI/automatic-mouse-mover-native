using System.Text.Json;
namespace SiymoMouseMover;
internal sealed class Settings
{
    public int IntervalSeconds { get; set; } = 60;
    public bool Enabled { get; set; } = true;
    public static string DefaultPath => Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "SiymoAI", "SiymoMouseMover", "settings.json");
    public static Settings Load(string path) {
        try { var value = JsonSerializer.Deserialize<Settings>(File.ReadAllText(path)) ?? new(); if (!new[] {30,60,120,300}.Contains(value.IntervalSeconds)) value.IntervalSeconds = 60; return value; }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException or JsonException) { return new(); }
    }
    public void Save(string path) {
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        var temp = path + ".tmp";
        File.WriteAllText(temp, JsonSerializer.Serialize(this, new JsonSerializerOptions { WriteIndented = true })); File.Move(temp, path, true);
    }
}
