import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();

const quests = [
  { title: "Moda Sahili'nde gün batımını izle", district: "Kadikoy" },
  { title: "Yeldegirmeni'nde yeni bir kahveci dene", district: "Kadikoy" },
  { title: "Bogaz manzarali bir yuruyus yap", district: "Besiktas" },
  { title: "Akaretler'de sokak foto cekimi yap", district: "Besiktas" },
  { title: "Karakoy'de yeni bir galeri kesfet", district: "Beyoglu" },
  { title: "Galata cevresinde 30 dakikalik mini tur", district: "Beyoglu" },
  { title: "Nisantasi'nda kitapci ziyareti yap", district: "Sisli" },
  { title: "Tesvikiye'de brunch dene", district: "Sisli" },
  { title: "Bebek sahilde kahve molasi", district: "Besiktas" },
  { title: "Caddebostan sahilde 5 km yuruyus", district: "Kadikoy" },
  { title: "Cihangir'de 2 yeni mekan gez", district: "Beyoglu" },
  { title: "Arnavutkoy'de tatli molasi", district: "Besiktas" },
  { title: "Kuzguncuk sokaklarinda fotograf turu", district: "Uskudar" },
  { title: "Uskudar sahilde cay ic", district: "Uskudar" },
  { title: "Bagdat Caddesi'nde vintage avina cik", district: "Kadikoy" },
  { title: "Kalamis marina cevresinde yuruyus", district: "Kadikoy" },
  { title: "Besiktas Carsi'da yeni lezzet dene", district: "Besiktas" },
  { title: "Ortakoy'de kumpir + sahil turu", district: "Besiktas" },
  { title: "Galataport'ta sergi gez", district: "Beyoglu" },
  { title: "Pera'da muzikli bir kafe kesfet", district: "Beyoglu" },
  { title: "Maiden's Tower manzarasinda bulus", district: "Uskudar" },
  { title: "Salacak sahilde gun dogumu planla", district: "Uskudar" },
  { title: "Bomonti'de kahve tadimi", district: "Sisli" },
  { title: "Macka Parki'nda mini piknik", district: "Besiktas" },
  { title: "Fenerbahce Parki'nda bisiklet turu", district: "Kadikoy" },
  { title: "Karakoy'de 3. nesil kahve dene", district: "Beyoglu" },
  { title: "Nisantasi'nda sokak sanati avla", district: "Sisli" },
  { title: "Besiktas iskelesinde cay + sohbet", district: "Besiktas" },
  { title: "Rasim Pasa'da mural turu", district: "Kadikoy" },
  { title: "Kuzguncuk'te butik kahvalti", district: "Uskudar" },
  { title: "Beyoglu'nda plakci gezisi", district: "Beyoglu" },
  { title: "Besiktas'ta board game cafe dene", district: "Besiktas" },
  { title: "Kadikoy Carsi'da sokak lezzeti avla", district: "Kadikoy" },
  { title: "Uskudar'da tarihi rota kesfet", district: "Uskudar" },
  { title: "Sisli'de tatli-kahve challenge", district: "Sisli" },
  { title: "Ortakoy sahilde 30 dk kosu", district: "Besiktas" },
  { title: "Kadikoy'de kitabevi + kahve ikilisi", district: "Kadikoy" },
  { title: "Galata koprusu cevresinde fotograf yuruyusu", district: "Beyoglu" },
  { title: "Nisantasi'nda sanat galerisi turu", district: "Sisli" },
  { title: "Uskudar Mihrimah cevresinde mini kesif", district: "Uskudar" },
  { title: "Kadikoy Moda'da dondurma molasi", district: "Kadikoy" },
  { title: "Besiktas'ta burger karsilastirmasi", district: "Besiktas" },
  { title: "Beyoglu'nda acik mikrofon gecesi", district: "Beyoglu" },
  { title: "Sisli'de cinema + kahve plani", district: "Sisli" },
  { title: "Uskudar'da sahil bench sohbeti", district: "Uskudar" },
  { title: "Kadikoy'de ikinci el pazar gezisi", district: "Kadikoy" },
  { title: "Besiktas'ta canli muzik dinle", district: "Besiktas" },
  { title: "Beyoglu'nda rooftop manzara molasi", district: "Beyoglu" },
  { title: "Sisli'de escape room challenge", district: "Sisli" },
  { title: "Uskudar'da gun batimi fotografi cek", district: "Uskudar" },
];

async function main() {
  const result = await prisma.quest.createMany({
    data: quests,
    skipDuplicates: true,
  });

  console.log(`Seed complete. Added ${result.count} quests.`);
}

main()
  .catch((error) => {
    console.error(error);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });

