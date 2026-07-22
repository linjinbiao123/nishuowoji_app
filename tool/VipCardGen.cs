using System;
using System.IO;
using System.Text;
using System.Drawing;
using System.Windows.Forms;
using System.Security.Cryptography;

public class VipCardGen : Form {
  private const long PermanentExpiry = 4102444800; // 2100-01-01，代表永久有效
  private TextBox txtDevice, txtDays, txtCard;
  private CheckBox chkBind, chkPerm;
  private string privHex, pubHex;

  [STAThread]
  static void Main() {
    Application.EnableVisualStyles();
    Application.SetCompatibleTextRenderingDefault(false);
    Application.Run(new VipCardGen());
  }

  public VipCardGen() {
    Text = "说记 · VIP 发卡工具";
    Width = 520; Height = 480;
    StartPosition = FormStartPosition.CenterScreen;
    FormBorderStyle = FormBorderStyle.FixedSingle;
    MaximizeBox = false;
    BackColor = Color.FromArgb(24, 33, 47);
    Font = new Font("Microsoft YaHei UI", 9.5f);

    var keyFile = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "vip_private_key.txt");
    bool hasKey = File.Exists(keyFile);
    if (hasKey) { var l = File.ReadAllLines(keyFile); privHex = l[0].Trim(); pubHex = l[1].Trim(); }

    var lblTitle = new Label { Text = "VIP 卡密生成器", ForeColor = Color.White, Font = new Font("Microsoft YaHei UI", 14, FontStyle.Bold), Location = new Point(20, 16), AutoSize = true };
    var lblTip = new Label { Text = hasKey ? "已加载发卡密钥，可直接生成卡密" : "未找到 vip_private_key.txt（请放在本程序同目录）", ForeColor = hasKey ? Color.FromArgb(120, 200, 160) : Color.FromArgb(240, 120, 120), Location = new Point(20, 54), AutoSize = true };

    var lblDev = new Label { Text = "设备码（买家在 App 里复制发给你）", ForeColor = Color.FromArgb(180, 190, 205), Location = new Point(20, 90), AutoSize = true };
    chkBind = new CheckBox { Text = "绑定设备（一机一码）", ForeColor = Color.FromArgb(200, 210, 225), Checked = true, Location = new Point(330, 87), AutoSize = true };
    chkBind.CheckedChanged += (s, e) => { txtDevice.Enabled = chkBind.Checked; };
    txtDevice = new TextBox { Location = new Point(20, 114), Width = 464, Font = new Font("Consolas", 11) };

    var lblDays = new Label { Text = "有效天数", ForeColor = Color.FromArgb(180, 190, 205), Location = new Point(20, 160), AutoSize = true };
    chkPerm = new CheckBox { Text = "永久有效", ForeColor = Color.FromArgb(200, 210, 225), Checked = false, Location = new Point(330, 157), AutoSize = true };
    chkPerm.CheckedChanged += (s, e) => { txtDays.Enabled = !chkPerm.Checked; };
    txtDays = new TextBox { Location = new Point(20, 184), Width = 120, Text = "365", Font = new Font("Consolas", 11) };

    var btnGen = new Button { Text = "生成卡密", Location = new Point(160, 180), Width = 150, Height = 33, BackColor = Color.FromArgb(56, 189, 248), ForeColor = Color.White, FlatStyle = FlatStyle.Flat, Font = new Font("Microsoft YaHei UI", 10, FontStyle.Bold) };
    btnGen.FlatAppearance.BorderSize = 0;
    btnGen.Click += BtnGen_Click;

    var lblCard = new Label { Text = "卡密（整段复制发给买家）", ForeColor = Color.FromArgb(180, 190, 205), Location = new Point(20, 236), AutoSize = true };
    txtCard = new TextBox { Location = new Point(20, 260), Width = 464, Height = 90, Multiline = true, ReadOnly = true, ScrollBars = ScrollBars.Vertical, BackColor = Color.FromArgb(15, 22, 34), ForeColor = Color.FromArgb(120, 220, 160), Font = new Font("Consolas", 10) };

    var btnCopy = new Button { Text = "复制卡密", Location = new Point(20, 362), Width = 120, Height = 32, BackColor = Color.FromArgb(40, 52, 70), ForeColor = Color.White, FlatStyle = FlatStyle.Flat };
    btnCopy.FlatAppearance.BorderColor = Color.FromArgb(70, 85, 105);
    btnCopy.Click += (s, e) => {
      if (!string.IsNullOrEmpty(txtCard.Text)) { Clipboard.SetText(txtCard.Text); MessageBox.Show("卡密已复制到剪贴板", "已复制", MessageBoxButtons.OK, MessageBoxIcon.Information); }
    };

    Controls.AddRange(new Control[] { lblTitle, lblTip, lblDev, chkBind, txtDevice, lblDays, chkPerm, txtDays, btnGen, lblCard, txtCard, btnCopy });
  }

  private void BtnGen_Click(object s, EventArgs e) {
    if (string.IsNullOrEmpty(privHex)) { MessageBox.Show("未找到密钥文件 vip_private_key.txt，请把它放在本程序同一目录下。", "缺少密钥", MessageBoxButtons.OK, MessageBoxIcon.Warning); return; }

    string dev = "";
    if (chkBind.Checked) {
      dev = txtDevice.Text.Trim();
      if (dev.Length < 6) { MessageBox.Show("请输入买家发来的设备码，或取消勾选「绑定设备」生成通用卡。", "设备码无效", MessageBoxButtons.OK, MessageBoxIcon.Warning); return; }
    }

    long exp;
    if (chkPerm.Checked) {
      exp = PermanentExpiry;
    } else {
      int days;
      if (!int.TryParse(txtDays.Text.Trim(), out days) || days <= 0) { MessageBox.Show("请输入有效的天数（正整数），或勾选「永久有效」。", "天数无效", MessageBoxButtons.OK, MessageBoxIcon.Warning); return; }
      exp = DateTimeOffset.UtcNow.ToUnixTimeSeconds() + (long)days * 86400;
    }

    try {
      txtCard.Text = Gen(privHex, pubHex, dev, exp);
    } catch (Exception ex) {
      MessageBox.Show("生成失败：" + ex.Message, "错误", MessageBoxButtons.OK, MessageBoxIcon.Error);
    }
  }

  static byte[] FromHex(string h) { var b = new byte[h.Length / 2]; for (int i = 0; i < b.Length; i++) b[i] = Convert.ToByte(h.Substring(i * 2, 2), 16); return b; }
  static string B64Url(byte[] d) { return Convert.ToBase64String(d).Replace('+', '-').Replace('/', '_'); }
  static string Gen(string privHex, string pubHex, string device, long exp) {
    long iat = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
    string payload = "{\"v\":1,\"exp\":" + exp + ",\"dev\":\"" + device + "\",\"iat\":" + iat + "}";
    byte[] msg = Encoding.UTF8.GetBytes(payload);
    byte[] pub = FromHex(pubHex);
    byte[] X = new byte[32], Y = new byte[32];
    Array.Copy(pub, 1, X, 0, 32); Array.Copy(pub, 33, Y, 0, 32);
    var p = new ECParameters { Curve = ECCurve.NamedCurves.nistP256, D = FromHex(privHex), Q = new ECPoint { X = X, Y = Y } };
    byte[] sig;
    using (var ec = ECDsa.Create()) { ec.ImportParameters(p); sig = ec.SignData(msg, HashAlgorithmName.SHA256); }
    return B64Url(msg) + "." + B64Url(sig);
  }
}
