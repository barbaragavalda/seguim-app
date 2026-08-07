/// Curated pool of "seguir"/"perdurar"-themed lines from well-known series
/// and movies, shown under the profile's welcome greeting. Spoken dialogue
/// only, never song lyrics. ca/es text is our own adaptation, not a claim
/// to be the official dub, except for mottos with a well-established
/// standard translation.
class ProfileQuote {
  const ProfileQuote({required this.text, required this.source});

  final String text;
  final String source;
}

const Map<String, List<ProfileQuote>> profileQuotesByLanguage = {
  'ca': [
    ProfileQuote(text: 'La Força serà amb tu, sempre.', source: 'Star Wars'),
    ProfileQuote(
      text: 'No puc portar-lo per tu, però et puc portar a tu.',
      source: 'El Senyor dels Anells',
    ),
    ProfileQuote(text: "L'hivern s'acosta.", source: 'Joc de Trons'),
    ProfileQuote(text: 'Recorda qui ets.', source: 'El Rei Lleó'),
    ProfileQuote(
      text: "Cap a l'infinit i més enllà!",
      source: 'Toy Story',
    ),
    ProfileQuote(
      text: 'Al final, tots som històries. Que almenys sigui una de bona.',
      source: 'Doctor Who',
    ),
    ProfileQuote(
      text: 'Carpe diem. Aprofiteu el dia.',
      source: 'El Club dels Poetes Morts',
    ),
    ProfileQuote(text: 'Sigues un peix de colors.', source: 'Ted Lasso'),
    ProfileQuote(
      text: 'El destí és curiós. Mai saps com aniran les coses.',
      source: 'Avatar: La Llegenda d\'Aang',
    ),
    ProfileQuote(
      text: 'El carrusel no deixa mai de girar.',
      source: 'Anatomia de Grey',
    ),
    ProfileQuote(text: 'El Nord recorda.', source: 'Joc de Trons (Sansa Stark)'),
    ProfileQuote(
      text: 'Que la sort estigui sempre de la teva banda.',
      source: 'Els Jocs de la Fam (Effie Trinket)',
    ),
    ProfileQuote(
      text: 'Un veritable perdedor és algú que té tanta por de no guanyar que ni tan sols ho intenta.',
      source: 'Little Miss Sunshine (avi Edwin)',
    ),
    ProfileQuote(
      text: 'Fem el que fem, ho farem junts.',
      source: 'Friends (Monica Geller)',
    ),
  ],
  'es': [
    ProfileQuote(text: 'La Fuerza te acompañará, siempre.', source: 'Star Wars'),
    ProfileQuote(
      text: 'No puedo llevarlo por ti, pero puedo llevarte a ti.',
      source: 'El Señor de los Anillos',
    ),
    ProfileQuote(text: 'Se acerca el invierno.', source: 'Juego de Tronos'),
    ProfileQuote(text: 'Recuerda quién eres.', source: 'El Rey León'),
    ProfileQuote(
      text: '¡Hasta el infinito y más allá!',
      source: 'Toy Story',
    ),
    ProfileQuote(
      text: 'Al final, todos somos historias. Que al menos sea una buena.',
      source: 'Doctor Who',
    ),
    ProfileQuote(
      text: 'Carpe diem. Aprovechad el día.',
      source: 'El Club de los Poetas Muertos',
    ),
    ProfileQuote(text: 'Sé un pez de colores.', source: 'Ted Lasso'),
    ProfileQuote(
      text: 'El destino es curioso. Nunca sabes cómo saldrán las cosas.',
      source: 'Avatar: La Leyenda de Aang',
    ),
    ProfileQuote(
      text: 'El carrusel nunca deja de girar.',
      source: 'Anatomía de Grey',
    ),
    ProfileQuote(text: 'El Norte recuerda.', source: 'Juego de Tronos (Sansa Stark)'),
    ProfileQuote(
      text: 'Que la suerte esté siempre de tu parte.',
      source: 'Los Juegos del Hambre (Effie Trinket)',
    ),
    ProfileQuote(
      text: 'Un verdadero perdedor es alguien que tiene tanto miedo a no ganar que ni siquiera lo intenta.',
      source: 'Pequeña Miss Sunshine (abuelo Edwin)',
    ),
    ProfileQuote(
      text: 'Hagamos lo que hagamos, lo haremos juntos.',
      source: 'Friends (Monica Geller)',
    ),
  ],
  'en': [
    ProfileQuote(text: 'The Force will be with you, always.', source: 'Star Wars'),
    ProfileQuote(
      text: "I can't carry it for you, but I can carry you.",
      source: 'The Lord of the Rings',
    ),
    ProfileQuote(text: 'Winter is coming.', source: 'Game of Thrones'),
    ProfileQuote(text: 'Remember who you are.', source: 'The Lion King'),
    ProfileQuote(text: 'To infinity and beyond!', source: 'Toy Story'),
    ProfileQuote(
      text: "We're all stories in the end. Just make it a good one.",
      source: 'Doctor Who',
    ),
    ProfileQuote(
      text: 'Carpe diem. Seize the day.',
      source: 'Dead Poets Society',
    ),
    ProfileQuote(text: 'Be a goldfish.', source: 'Ted Lasso'),
    ProfileQuote(
      text: "Destiny is a funny thing. You never know how things are going to work out.",
      source: 'Avatar: The Last Airbender',
    ),
    ProfileQuote(
      text: 'The carousel never stops turning.',
      source: "Grey's Anatomy",
    ),
    ProfileQuote(text: 'The North remembers.', source: 'Game of Thrones (Sansa Stark)'),
    ProfileQuote(
      text: 'May the odds be ever in your favor.',
      source: 'The Hunger Games (Effie Trinket)',
    ),
    ProfileQuote(
      text: "A real loser is someone who's so afraid of not winning, they don't even try.",
      source: 'Little Miss Sunshine (Grandpa Edwin)',
    ),
    ProfileQuote(
      text: "Whatever we do, we're gonna do it together.",
      source: 'Friends (Monica Geller)',
    ),
  ],
};
