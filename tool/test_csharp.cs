using System;
using System.IO;
using System.Text;
using System.Security.Cryptography;

public class VipGenTest {
  const long Perm = 4102444800;
  static byte[] FromHex(string h){ var b=new byte[h.Length/2]; for(int i=0;i<b.Length;i++) b[i]=Convert.ToByte(h.Substring(i*2,2),16); return b; }
  static string B64Url(byte[] d){ return Convert.ToBase64String(d).Replace('+','-').Replace('/','_'); }
  public static string Gen(string privHex, string pubHex, string device, long exp){
    long iat = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
    string payload = "{\"v\":1,\"exp\":" + exp + ",\"dev\":\"" + device + "\",\"iat\":" + iat + "}";
    byte[] msg = Encoding.UTF8.GetBytes(payload);
    byte[] pub = FromHex(pubHex);
    byte[] X = new byte[32], Y = new byte[32];
    Array.Copy(pub,1,X,0,32); Array.Copy(pub,33,Y,0,32);
    var p = new ECParameters { Curve = ECCurve.NamedCurves.nistP256, D = FromHex(privHex), Q = new ECPoint { X = X, Y = Y } };
    byte[] sig;
    using(var ec = ECDsa.Create()){ ec.ImportParameters(p); sig = ec.SignData(msg, HashAlgorithmName.SHA256); }
    return B64Url(msg) + "." + B64Url(sig);
  }
  public static void Main(){
    var l = File.ReadAllLines("tool/vip_private_key.txt");
    string priv=l[0].Trim(), pub=l[1].Trim();
    long now = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
    Console.WriteLine("UNIVERSAL_PERM=" + Gen(priv, pub, "", Perm));
    Console.WriteLine("BOUND_365=" + Gen(priv, pub, "eb13c9a2a7a4e3ac", now + 365L*86400));
  }
}
